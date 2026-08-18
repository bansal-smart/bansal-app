import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

class _TestDetails {
  final String id;
  final String title;
  final String description;
  final String testType;
  final String examPattern;
  final List<String> subjects;
  final int durationMinutes;
  final int totalQuestions;
  final double totalMarks;
  final double correctMarks;
  final double wrongMarks;

  const _TestDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.testType,
    required this.examPattern,
    required this.subjects,
    required this.durationMinutes,
    required this.totalQuestions,
    required this.totalMarks,
    required this.correctMarks,
    required this.wrongMarks,
  });

  factory _TestDetails.fromJson(Map<String, dynamic> j) => _TestDetails(
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Test',
    description: j['description'] as String? ?? '',
    testType: j['test_type'] as String? ?? '',
    examPattern: j['exam_pattern'] as String? ?? '',
    subjects: (j['subjects'] as List<dynamic>?)?.map((s) => s.toString()).toList() ?? [],
    durationMinutes: j['duration_minutes'] as int? ?? 0,
    totalQuestions: j['total_questions'] as int? ?? 0,
    totalMarks: _toDouble(j['total_marks']),
    correctMarks: _toDouble(j['correct_marks']),
    wrongMarks: _toDouble(j['wrong_marks']),
  );

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────────────────────────────
// TEST INSTRUCTIONS SCREEN — mirrors web's TestInstructionsPage
// ─────────────────────────────────────────────
class TestInstructionsScreen extends StatefulWidget {
  final String testId;
  const TestInstructionsScreen({super.key, required this.testId});

  @override
  State<TestInstructionsScreen> createState() => _TestInstructionsScreenState();
}

class _TestInstructionsScreenState extends State<TestInstructionsScreen> {
  bool _loading = true;
  String? _error;
  _TestDetails? _test;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.client
          .from('tests')
          .select(
            'id, title, description, test_type, exam_pattern, subjects, '
            'duration_minutes, total_questions, total_marks, correct_marks, wrong_marks',
          )
          .eq('id', widget.testId)
          .single();
      setState(() {
        _test = _TestDetails.fromJson(data);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppException.from(e).userMessage;
        _loading = false;
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
        backgroundColor: DS.background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: DS.primary))
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : _buildContent(_test!),
        ),
      ),
    );
  }

  Widget _buildContent(_TestDetails t) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/tests'),
                icon: const Icon(Icons.arrow_back_rounded, color: DS.textPrimary),
              ),
              const Text(
                'All tests',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s8, DS.s16, DS.s32),
            children: [
              _HeroCard(test: t),
              const SizedBox(height: DS.s16),
              _InstructionsCard(test: t),
              const SizedBox(height: DS.s20),
              _AgreementRow(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
              ),
              const SizedBox(height: DS.s16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _agreed
                      ? () {
                          HapticFeedback.selectionClick();
                          context.pushReplacement('/test/${t.id}');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DS.primary,
                    disabledBackgroundColor: DS.primary.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Start Test',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: DS.s10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/tests'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DS.textPrimary,
                    side: const BorderSide(color: DS.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HERO CARD — gradient, badge, title, description, stat grid
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final _TestDetails test;
  const _HeroCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final badge = [test.examPattern, test.testType]
        .where((p) => p.isNotEmpty)
        .map((p) => p.toUpperCase())
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(DS.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF7A00), DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge.isNotEmpty)
            Text(
              badge,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          const SizedBox(height: DS.s6),
          Text(
            test.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (test.description.isNotEmpty) ...[
            const SizedBox(height: DS.s8),
            Text(
              test.description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: DS.s20),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.access_time_rounded,
                  label: 'DURATION',
                  value: '${test.durationMinutes} min',
                ),
              ),
              const SizedBox(width: DS.s10),
              Expanded(
                child: _StatChip(
                  icon: Icons.description_outlined,
                  label: 'QUESTIONS',
                  value: '${test.totalQuestions}',
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s10),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.verified_outlined,
                  label: 'TOTAL MARKS',
                  value: _HeroCard._fmtMark(test.totalMarks),
                ),
              ),
              const SizedBox(width: DS.s10),
              Expanded(
                child: _StatChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'MARKING',
                  value:
                      '+${_fmtMark(test.correctMarks)} / ${_fmtMark(test.wrongMarks)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtMark(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 13),
              const SizedBox(width: DS.s4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INSTRUCTIONS CARD — numbered list + palette legend + subjects
// ─────────────────────────────────────────────
class _InstructionsCard extends StatelessWidget {
  final _TestDetails test;
  const _InstructionsCard({required this.test});

  static const _legend = [
    (Color(0xFFE5E7EB), Color(0xFF6B7280), 'Not Visited'),
    (Color(0xFFEF4444), Colors.white, 'Not Answered'),
    (Color(0xFF10B981), Colors.white, 'Answered'),
    (Color(0xFF8B5CF6), Colors.white, 'Marked for Review'),
    (Color(0xFF8B5CF6), Colors.white, 'Answered & Marked (evaluated)'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      'The total duration is ${test.durationMinutes} minutes. The clock starts the moment you click Start Test and cannot be paused.',
      'The test will auto-submit when the timer hits zero. Any unsaved answer is preserved.',
      'Each correct answer carries +${_HeroCard._fmtMark(test.correctMarks)} mark(s). Each wrong answer carries ${_HeroCard._fmtMark(test.wrongMarks)}. Unanswered questions are not penalised.',
      'You may navigate freely between questions using the palette on the right. Status colours are listed below.',
      'Use Save & Next to record an answer, Mark for Review to flag a question. Answered & marked questions are still evaluated.',
      'Do not refresh, close, or navigate away during the test. Progress is saved automatically every few seconds.',
    ];

    return Container(
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'General instructions',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s14),
          for (int i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: DS.s10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  const SizedBox(width: DS.s8),
                  Expanded(
                    child: Text(
                      items[i],
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: DS.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: DS.s8),
          const Text(
            'QUESTION PALETTE LEGEND',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: DS.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: DS.s12),
          for (final (bg, fg, label) in _legend)
            Padding(
              padding: const EdgeInsets.only(bottom: DS.s10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '1',
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s10),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 13.5, color: DS.textPrimary),
                  ),
                ],
              ),
            ),
          if (test.subjects.isNotEmpty) ...[
            const SizedBox(height: DS.s4),
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13.5, color: DS.textPrimary),
                children: [
                  const TextSpan(
                    text: 'Subjects: ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: test.subjects.join(' · '),
                    style: const TextStyle(color: DS.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AGREEMENT CHECKBOX ROW
// ─────────────────────────────────────────────
class _AgreementRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const _AgreementRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(DS.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DS.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: DS.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: DS.s6),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: DS.s10),
                child: Text(
                  'I have read and understood the instructions. I declare that '
                  'I will not use any unfair means during the test and that any '
                  'malpractice may lead to disqualification.',
                  style: TextStyle(
                    fontSize: 13,
                    color: DS.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: DS.error, size: 36),
            const SizedBox(height: DS.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DS.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: DS.s16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
