import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/supabase/supabase_client.dart';
import '../enrollments/data/repositories/enrollments_repository.dart';
import 'data/auth_repository.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
abstract class _C {
  static const primary = Color(0xFF193F8F);
  static const primaryBg = Color(0xFFE8EDF9); // single chip background
  static const bg = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
}

// ── Data ───────────────────────────────────────────────────────────────────
// Display label, icon, and canonical database value. The database values
// match the web profile flow so app-created students stay compatible with
// web filters and course targeting.
const _kTargetExams = [
  ('IIT-JEE', '⚗️', 'IIT-JEE'),
  ('NEET', '🧬', 'NEET'),
  ('Pre-Foundation', '📚', 'Pre Foundation'),
];

const _kClasses = [
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  '10',
  '11',
  '12',
  'Dropper',
];

// ── Screen ─────────────────────────────────────────────────────────────────
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _pageCtrl = PageController();
  final _nameCtrl = TextEditingController();

  // steps: 0=name, 1=exam, 2=class
  int _step = 0;
  String _name = '';
  String _selExam = '';
  String _selClass = '';
  String? _nameError;
  String? _saveError;
  bool _saving = false;

  static const int _totalSteps = 3;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onNameNext() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your name');
      return;
    }
    setState(() {
      _name = name;
      _nameError = null;
    });
    FocusScope.of(context).unfocus();
    _goToStep(1);
  }

  void _onExamSelected(String exam) {
    setState(() {
      _selExam = exam;
      _selClass = ''; // reset class when exam changes
      _saveError = null;
    });
    Future.delayed(const Duration(milliseconds: 180), () => _goToStep(2));
  }

  void _onClassSelected(String cls) {
    setState(() {
      _selClass = cls;
      _saveError = null;
    });
  }

  Future<void> _finish() async {
    if (_selClass.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final prefs = ref.read(prefsProvider);
    final sb = supabaseOrNull;
    final uid = sb?.auth.currentUser?.id;
    final authRepo = ref.read(authRepositoryProvider);

    // New student: the account is created server-side from these details.
    if (uid == null && authRepo.hasPendingRegistration) {
      try {
        await authRepo.completePhoneRegistration(
          fullName: _name,
          classLevel: _selClass,
          targetExam: _selExam,
        );
        ref.read(authStateProvider.notifier).refresh();
        await EnrollmentsRepository().autoEnrollFreeCourses(
          exam: prefs.userExam,
          userClass: prefs.userClass,
        );
        if (!mounted) return;
        ref.read(needsProfileSetupProvider.notifier).state = false;
        context.go('/home');
      } catch (e) {
        debugPrint('[ProfileSetup] Registration error: $e');
        if (!mounted) return;
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _saving = false;
          _saveError =
              msg.contains('closed') ||
                  msg.contains('expired') ||
                  msg.contains('invalid') ||
                  msg.contains('suspended')
              ? msg
              : 'We could not create your profile. Please try again.';
        });
      }
      return;
    }

    if (sb == null || uid == null) {
      setState(() {
        _saving = false;
        _saveError = 'Your session expired. Please verify your number again.';
      });
      return;
    }

    final storedPhone = prefs.phoneNumber.trim();
    final phone = storedPhone.isEmpty
        ? null
        : storedPhone.startsWith('+')
        ? storedPhone
        : '+91$storedPhone';

    try {
      final payload = {
        'user_id': uid,
        'full_name': _name,
        'class_level': _selClass,
        'target_exam': _selExam,
        'phone': phone,
        'onboarding_completed': true,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await sb.from('profiles').upsert(payload, onConflict: 'user_id');

      // Only mark setup complete locally after Supabase accepted the profile.
      // This guarantees the account also appears with complete details in the
      // super-admin student/user views.
      await prefs.setUserName(_name);
      await prefs.setUserClass(_selClass);
      await prefs.setUserExam(_selExam);
      await prefs.setProfileSetupDone(true);

      await EnrollmentsRepository().autoEnrollFreeCourses(
        exam: _selExam,
        userClass: _selClass,
      );

      if (!mounted) return;
      ref.read(needsProfileSetupProvider.notifier).state = false;
      context.go('/home');
    } catch (e) {
      debugPrint('[ProfileSetup] DB save error: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'We could not create your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                step: _step,
                totalSteps: _totalSteps,
                onBack: _step == 0
                    ? () async {
                        ref
                            .read(authRepositoryProvider)
                            .clearPendingRegistration();
                        await supabaseOrNull?.auth.signOut();
                        if (context.mounted) context.go('/login');
                      }
                    : () => _goToStep(_step - 1),
              ),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Step 0 — Name
                    _NameStep(
                      controller: _nameCtrl,
                      error: _nameError,
                      onNext: _onNameNext,
                    ),
                    // Step 1 — Exam / Goal
                    _ExamStep(
                      name: _name,
                      selected: _selExam,
                      onSelect: _onExamSelected,
                    ),
                    // Step 2 — Class (filtered by exam)
                    _ClassStep(
                      name: _name,
                      selected: _selClass,
                      onSelect: _onClassSelected,
                      onSubmit: _finish,
                      saving: _saving,
                      error: _saveError,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top bar ────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;

  const _TopBar({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: _C.textPrimary),
            onPressed:
                onBack ??
                () {
                  if (context.canPop()) context.pop();
                },
          ),
          const Spacer(),
          Row(
            children: List.generate(totalSteps, (i) {
              final active = i == step;
              final passed = i < step;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: (active || passed)
                      ? _C.primary
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Shared header widget ───────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final String name;
  final String emoji;
  final String question;
  final String? imagePath;

  const _StepHeader({
    required this.name,
    required this.emoji,
    required this.question,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, ${name.isNotEmpty ? name : "there"} 👋',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Let's customize your Bansal journey",
          style: TextStyle(fontSize: 14, color: _C.textSub),
        ),
        const SizedBox(height: 32),
        Center(
          child: imagePath != null
              ? Image.asset(imagePath!, height: 140, fit: BoxFit.contain)
              : Text(emoji, style: const TextStyle(fontSize: 72)),
        ),
        const SizedBox(height: 28),
        Text(
          question,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _C.textPrimary,
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

// ── Option chip ────────────────────────────────────────────────────────────
class _OptionChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? _C.primary : _C.primaryBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _C.primary : _C.primary.withValues(alpha: 0.20),
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _C.primary.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : _C.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 0: Name ───────────────────────────────────────────────────────────
class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final VoidCallback onNext;

  const _NameStep({
    required this.controller,
    required this.error,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hi, 👋',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Let's customize your Bansal journey",
            style: TextStyle(fontSize: 14, color: _C.textSub),
          ),
          const SizedBox(height: 36),
          const Text(
            "What's your name?",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _C.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _C.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
              filled: true,
              fillColor: _C.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: error != null ? const Color(0xFFEF4444) : _C.primary,
                  width: 1.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => onNext(),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5),
            ),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Exam / Goal ────────────────────────────────────────────────────
class _ExamStep extends StatelessWidget {
  final String name;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ExamStep({
    required this.name,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            name: name,
            emoji: '🎯',
            question: 'Select your target exam',
          ),
          // 2-column grid (Foundation sits alone in second row, centered)
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.4,
            physics: const NeverScrollableScrollPhysics(),
            children: _kTargetExams
                .map(
                  (e) => _OptionChip(
                    label: e.$1,
                    emoji: e.$2,
                    isSelected: selected == e.$3,
                    onTap: () => onSelect(e.$3),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: Class (filtered by exam) ──────────────────────────────────────
class _ClassStep extends StatelessWidget {
  final String name;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onSubmit;
  final bool saving;
  final String? error;

  const _ClassStep({
    required this.name,
    required this.selected,
    required this.onSelect,
    required this.onSubmit,
    required this.saving,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepHeader(
            name: name,
            emoji: '✏️',
            imagePath: 'assets/images/class.jpg',
            question: 'I am studying in class',
          ),
          DropdownButtonFormField<String>(
            key: ValueKey(selected),
            initialValue: selected.isEmpty ? null : selected,
            isExpanded: true,
            hint: const Text('Select your class'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            decoration: InputDecoration(
              filled: true,
              fillColor: _C.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _C.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.primary, width: 2),
              ),
            ),
            items: _kClasses
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'Dropper' ? 'Dropper' : 'Class $value',
                    ),
                  ),
                )
                .toList(),
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) onSelect(value);
                  },
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: selected.isEmpty || saving ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _C.border,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create My Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
