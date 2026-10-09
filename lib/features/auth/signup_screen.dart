import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/error/app_exception.dart';
import 'data/auth_repository.dart';

// ─── Import DS from login_screen.dart (or move DS to a shared file) ───
// Make sure DS class is accessible here. Ideally move DS to:
// lib/core/theme/design_system.dart  and import it everywhere.

// ─────────────────────────────────────────────
// 🎨  DESIGN SYSTEM — same tokens as LoginScreen
//     Move this to lib/core/theme/design_system.dart
//     and import across all screens.
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);

  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s48 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// SIGNUP SCREEN
// ─────────────────────────────────────────────
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String _countryCode = '+91';
  String _targetExam = 'IIT JEE';
  String _classLevel = 'Class 11';
  String _country = 'India';
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _ctrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _cardFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final region = ref.read(regionProvider);
      final repo = ref.read(authRepositoryProvider);
      // Store password so it can be set after OTP verification
      repo.pendingPassword = _passwordCtrl.text;
      await repo.signUp(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: '$_countryCode ${_phoneCtrl.text.trim()}',
        region: region,
      );
      if (!mounted) return;
      context.push(
        '/verify-otp?email=${Uri.encodeComponent(_emailCtrl.text.trim())}',
      );
    } catch (e) {
      setState(() => _error = AppException.from(e).userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(regionProvider);
    _countryCode = region == 'AE' ? '+971' : '+91';

    return Scaffold(
      backgroundColor: DS.primary,
      body: Stack(
        children: [
          // ── Decorative background ──
          const _HeroDecorations(),

          Column(
            children: [
              // ── Hero / Branding — smaller than login since more fields ──
              Expanded(
                flex: 28,
                child: SafeArea(
                  bottom: false,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: const _HeroSection(),
                  ),
                ),
              ),

              // ── Scrollable form card ──
              Expanded(
                flex: 72,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: _FormCard(
                      form: _form,
                      nameCtrl: _nameCtrl,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      phoneCtrl: _phoneCtrl,
                      cityCtrl: _cityCtrl,
                      countryCode: _countryCode,
                      targetExam: _targetExam,
                      classLevel: _classLevel,
                      country: _country,
                      loading: _loading,
                      obscurePassword: _obscurePassword,
                      error: _error,
                      onCountryCodeChanged: (v) =>
                          setState(() => _countryCode = v ?? _countryCode),
                      onExamChanged: (v) =>
                          setState(() => _targetExam = v ?? _targetExam),
                      onClassChanged: (v) =>
                          setState(() => _classLevel = v ?? _classLevel),
                      onCountryChanged: (v) =>
                          setState(() => _country = v ?? _country),
                      onTogglePassword: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmit: _submit,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO DECORATIONS (same as LoginScreen)
// ─────────────────────────────────────────────
class _HeroDecorations extends StatelessWidget {
  const _HeroDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -50,
          child: _Circle(size: 220, opacity: 0.10),
        ),
        Positioned(
          top: 40,
          left: -40,
          child: _Circle(size: 130, opacity: 0.07),
        ),
        Positioned(top: 20, right: 60, child: _Circle(size: 55, opacity: 0.12)),
        Positioned(
          top: 100,
          right: -20,
          child: Transform.rotate(
            angle: math.pi / 6,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

// ─────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo pill — smaller since hero is compact
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: DS.s16),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Join Us Today! 🚀',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                'Start your preparation journey',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.80),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FORM CARD
// ─────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> form;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController cityCtrl;
  final String countryCode;
  final String targetExam;
  final String classLevel;
  final String country;
  final bool loading;
  final bool obscurePassword;
  final String? error;
  final ValueChanged<String?> onCountryCodeChanged;
  final ValueChanged<String?> onExamChanged;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onCountryChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.form,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.countryCode,
    required this.targetExam,
    required this.classLevel,
    required this.country,
    required this.loading,
    required this.obscurePassword,
    required this.error,
    required this.onCountryCodeChanged,
    required this.onExamChanged,
    required this.onClassChanged,
    required this.onCountryChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: DS.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DS.radiusXl),
          topRight: Radius.circular(DS.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DS.s24, DS.s28, DS.s24, DS.s32),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Card header ──
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: DS.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: DS.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Fill in your details to get started',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: DS.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: DS.s20),

              // ── Divider ──
              Row(
                children: [
                  Expanded(child: Divider(color: DS.border, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DS.s12),
                    child: Text(
                      'signup with email',
                      style: TextStyle(
                        fontSize: 12,
                        color: DS.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: DS.border, thickness: 1)),
                ],
              ),

              const SizedBox(height: DS.s16),

              // ── Section: Personal Info ──
              _SectionLabel(
                label: 'Personal Info',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: DS.s12),

              // Full Name
              _AppField(
                controller: nameCtrl,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: DS.s12),

              // Phone row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code dropdown — no prefix icon so the code text is fully visible
                  SizedBox(
                    width: 125,
                    child: DropdownButtonFormField<String>(
                      value: countryCode,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: DS.textSecondary,
                        size: 16,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: DS.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      dropdownColor: DS.surface,
                      decoration: InputDecoration(
                        hintText: 'Code',
                        hintStyle: const TextStyle(
                          color: DS.textHint,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: DS.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: DS.s8,
                          vertical: DS.s16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          borderSide: const BorderSide(color: DS.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          borderSide: const BorderSide(
                            color: DS.border,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          borderSide: const BorderSide(
                            color: DS.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '+91',
                          child: Text(
                            '🇮🇳 +91',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: '+971',
                          child: Text(
                            '🇦🇪 +971',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      onChanged: onCountryCodeChanged,
                    ),
                  ),
                  const SizedBox(width: DS.s8),
                  // Phone number
                  Expanded(
                    child: _AppField(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      hint: '9876543210',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.length < 7)
                          ? 'Enter valid phone'
                          : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: DS.s20),

              // ── Section: Account Info ──
              _SectionLabel(
                label: 'Account Info',
                icon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: DS.s12),

              // Email
              _AppField(
                controller: emailCtrl,
                label: 'Email Address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: DS.s12),

              // Password
              _AppField(
                controller: passwordCtrl,
                label: 'Create Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: obscurePassword,
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                suffix: GestureDetector(
                  onTap: onTogglePassword,
                  child: Padding(
                    padding: const EdgeInsets.all(DS.s12),
                    child: Icon(
                      obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: DS.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: DS.s20),

              // ── Section: Academic Profile ──
              _SectionLabel(
                label: 'Academic Profile',
                icon: Icons.school_outlined,
              ),
              const SizedBox(height: DS.s12),

              // Target Exam + Class — side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _DropdownField<String>(
                      value: targetExam,
                      hint: 'Target Exam',
                      icon: Icons.flag_outlined,
                      items: const ['IIT JEE', 'NEET', 'Foundation'],
                      labels: const ['IIT JEE', 'NEET', 'Foundation'],
                      onChanged: onExamChanged,
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Expanded(
                    child: _DropdownField<String>(
                      value: classLevel,
                      hint: 'Class',
                      icon: Icons.class_outlined,
                      items: const ['Class 11', 'Class 12', 'Dropper'],
                      labels: const ['Class 11', 'Class 12', 'Dropper'],
                      onChanged: onClassChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DS.s12),

              // City + Country — side by side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AppField(
                      controller: cityCtrl,
                      label: 'City',
                      hint: 'Your city',
                      icon: Icons.location_on_outlined,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Expanded(
                    child: _DropdownField<String>(
                      value: country,
                      hint: 'Country',
                      icon: Icons.public_outlined,
                      items: const ['India', 'UAE'],
                      labels: const ['India', 'UAE'],
                      onChanged: onCountryChanged,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: DS.s20),

              // ── Error banner ──
              if (error != null) ...[
                _ErrorBanner(message: error!),
                const SizedBox(height: DS.s12),
              ],

              // ── Create Account button ──
              _PrimaryButton(
                label: 'Create Account',
                loading: loading,
                onTap: loading ? null : onSubmit,
              ),

              const SizedBox(height: DS.s20),

              // ── Login redirect ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account? ',
                    style: TextStyle(color: DS.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: DS.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Section Label
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionLabel({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(DS.s6),
          decoration: BoxDecoration(
            color: DS.primaryLight,
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Icon(icon, size: 14, color: DS.primary),
        ),
        const SizedBox(width: DS.s8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: DS.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: DS.s8),
        Expanded(child: Divider(color: DS.border, thickness: 1)),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Text Field (same as LoginScreen)
// ─────────────────────────────────────────────
class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _AppField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: DS.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 20, color: DS.textSecondary),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: DS.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.error, width: 1.8),
        ),
        errorStyle: const TextStyle(color: DS.error, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Dropdown Field
// ─────────────────────────────────────────────
class _DropdownField<T> extends StatelessWidget {
  final T value;
  final String hint;
  final IconData icon;
  final List<T> items;
  final List<String> labels;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: DS.textSecondary,
        size: 20,
      ),
      style: const TextStyle(
        fontSize: 14,
        color: DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: DS.surface,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 18, color: DS.textSecondary),
        ),
        filled: true,
        fillColor: DS.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.primary, width: 1.8),
        ),
      ),
      items: List.generate(
        items.length,
        (i) => DropdownMenuItem<T>(
          value: items[i],
          child: Text(
            labels[i],
            style: const TextStyle(fontSize: 13.5, color: DS.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Primary Button (same as LoginScreen)
// ─────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF2B5BB8), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(DS.radiusMd),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: DS.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// REUSABLE: Error Banner (same as LoginScreen)
// ─────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      decoration: BoxDecoration(
        color: DS.errorSurface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: DS.error, size: 18),
          const SizedBox(width: DS.s8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DS.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
