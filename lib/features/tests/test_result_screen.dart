import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/motion.dart';
import '../../skeleton_loading/test_result_skeleton.dart';
import 'data/scorecard_pdf.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
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
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFFFBEB);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);
  static const muted = Color(0xFF94A3B8);
  static const orange = Color(0xFFF97316);

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// RESULT BUNDLE — parsed from get_test_result_bundle RPC
// ─────────────────────────────────────────────
class SubjectStat {
  final String subject;
  final int attempted;
  final int correct;
  final int total;
  final double score;
  final double maxScore;

  const SubjectStat({
    required this.subject,
    required this.attempted,
    required this.correct,
    required this.total,
    required this.score,
    required this.maxScore,
  });

  double get accuracy => attempted == 0 ? 0 : (correct / attempted) * 100;
}

class RankInfo {
  final bool released;
  final bool excluded;
  final DateTime? releaseAt;
  final int? rank;
  final int? totalAttempts;
  final double? percentile;
  final double? topperScore;
  final double? averageScore;

  const RankInfo({
    required this.released,
    required this.excluded,
    this.releaseAt,
    this.rank,
    this.totalAttempts,
    this.percentile,
    this.topperScore,
    this.averageScore,
  });

  factory RankInfo.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const RankInfo(released: false, excluded: false);
    return RankInfo(
      released: j['released'] as bool? ?? false,
      excluded: j['excluded'] as bool? ?? false,
      releaseAt: j['release_at'] != null
          ? DateTime.tryParse(j['release_at'] as String)
          : null,
      rank: (j['rank'] as num?)?.toInt(),
      totalAttempts: (j['total'] as num?)?.toInt(),
      percentile: (j['percentile'] as num?)?.toDouble(),
      topperScore: (j['topper_score'] as num?)?.toDouble(),
      averageScore: (j['average_score'] as num?)?.toDouble(),
    );
  }
}

class TestResultBundle {
  final String attemptId;
  final String testId;
  final String testName;
  final double score;
  final double totalMarks;
  final int totalQuestions;
  final int correctAnswers;
  final int attemptedCount;
  final int timeSpentSeconds;
  final DateTime? endsAt;
  final List<SubjectStat> subjects;
  final RankInfo rank;

  const TestResultBundle({
    required this.attemptId,
    required this.testId,
    required this.testName,
    required this.score,
    required this.totalMarks,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.attemptedCount,
    required this.timeSpentSeconds,
    this.endsAt,
    required this.subjects,
    required this.rank,
  });

  int get wrong => attemptedCount - correctAnswers;
  int get unattempted => totalQuestions - attemptedCount;
  double get accuracy =>
      attemptedCount == 0 ? 0 : (correctAnswers / attemptedCount) * 100;

  factory TestResultBundle.fromJson(Map<String, dynamic> j) {
    final attempt = (j['attempt'] as Map).cast<String, dynamic>();
    final test = (j['test'] as Map?)?.cast<String, dynamic>();
    final subjectsMax =
        (j['subjects_max'] as Map?)?.cast<String, dynamic>() ?? {};
    final metadata =
        (attempt['metadata'] as Map?)?.cast<String, dynamic>() ?? {};

    final metaSubjects =
        (metadata['subjects'] as Map?)?.cast<String, dynamic>() ?? {};
    final metaQuestions =
        (metadata['questions'] as List?)
            ?.map((e) => (e as Map).cast<String, dynamic>())
            .toList() ??
        const [];

    final subjectAttempted = <String, int>{};
    final subjectCorrect = <String, int>{};
    for (final q in metaQuestions) {
      final subj = q['subject'] as String? ?? 'General';
      if (q['attempted'] == true) {
        subjectAttempted[subj] = (subjectAttempted[subj] ?? 0) + 1;
      }
      if (q['is_correct'] == true) {
        subjectCorrect[subj] = (subjectCorrect[subj] ?? 0) + 1;
      }
    }

    final subjectNames = {
      ...subjectsMax.keys,
      ...metaSubjects.keys,
      ...subjectAttempted.keys,
    };

    final subjects = subjectNames.map((name) {
      final maxInfo = (subjectsMax[name] as Map?)?.cast<String, dynamic>();
      final total =
          (maxInfo?['total'] as num?)?.toInt() ?? subjectAttempted[name] ?? 0;
      final maxScore = (maxInfo?['max_score'] as num?)?.toDouble() ?? 0;
      final score = (metaSubjects[name] as num?)?.toDouble() ?? 0;
      return SubjectStat(
        subject: name,
        attempted: subjectAttempted[name] ?? 0,
        correct: subjectCorrect[name] ?? 0,
        total: total,
        score: score,
        maxScore: maxScore,
      );
    }).toList()..sort((a, b) => a.subject.compareTo(b.subject));

    return TestResultBundle(
      attemptId: attempt['id'] as String,
      testId: attempt['test_id'] as String,
      testName:
          attempt['test_name'] as String? ??
          test?['title'] as String? ??
          'Test',
      score: (attempt['score'] as num?)?.toDouble() ?? 0,
      totalMarks:
          (test?['total_marks'] as num?)?.toDouble() ??
          (metadata['total'] as num?)?.toDouble() ??
          0,
      totalQuestions: (attempt['total_questions'] as num?)?.toInt() ?? 0,
      correctAnswers: (attempt['correct_answers'] as num?)?.toInt() ?? 0,
      attemptedCount: (metadata['attempted'] as num?)?.toInt() ?? 0,
      timeSpentSeconds: (attempt['time_spent_seconds'] as num?)?.toInt() ?? 0,
      endsAt: test?['ends_at'] != null
          ? DateTime.tryParse(test!['ends_at'] as String)
          : null,
      subjects: subjects,
      rank: RankInfo.fromJson((j['rank'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

// ─────────────────────────────────────────────
// RE-ATTEMPT REQUEST STATUS
// ─────────────────────────────────────────────
enum ReattemptStatus { none, pending, approved, rejected }

// ─────────────────────────────────────────────
// TEST RESULT SCREEN
// ─────────────────────────────────────────────
class TestResultScreen extends StatefulWidget {
  final String attemptId;
  const TestResultScreen({super.key, required this.attemptId});

  @override
  State<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends State<TestResultScreen> {
  bool _loading = true;
  String? _error;
  TestResultBundle? _bundle;
  ReattemptStatus _reattemptStatus = ReattemptStatus.none;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.client.rpc(
        'get_test_result_bundle',
        params: {'_attempt_id': widget.attemptId},
      );
      final bundle = TestResultBundle.fromJson(
        (data as Map).cast<String, dynamic>(),
      );

      await _loadReattemptStatus(bundle.testId);
      _startCountdownIfNeeded(bundle);

      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AppException.from(e).userMessage;
        _loading = false;
      });
    }
  }

  Future<void> _loadReattemptStatus(String testId) async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await SupabaseService.client
          .from('test_reattempt_requests')
          .select('status, consumed_at')
          .eq('user_id', userId)
          .eq('test_id', testId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final status = row?['status'] as String?;
      final consumed = row?['consumed_at'] != null;
      _reattemptStatus = switch (status) {
        'pending' => ReattemptStatus.pending,
        'approved' when !consumed => ReattemptStatus.approved,
        'rejected' => ReattemptStatus.rejected,
        _ => ReattemptStatus.none,
      };
    } catch (_) {
      // Non-fatal — leave as "none" so the request button still shows.
    }
  }

  void _startCountdownIfNeeded(TestResultBundle bundle) {
    _countdownTimer?.cancel();
    final releaseAt = bundle.rank.releaseAt ?? bundle.endsAt;
    if (bundle.rank.released || releaseAt == null) return;

    void tick() {
      final rem = releaseAt.difference(DateTime.now());
      if (!mounted) return;
      if (rem.isNegative) {
        _countdownTimer?.cancel();
        _load(); // release time passed — refetch to pick up rank data
        return;
      }
      setState(() => _remaining = rem);
    }

    tick();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Future<void> _submitReattemptRequest(String reason) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    final bundle = _bundle;
    if (userId == null || bundle == null) return;
    try {
      await SupabaseService.client.from('test_reattempt_requests').insert({
        'user_id': userId,
        'test_id': bundle.testId,
        'attempt_id': bundle.attemptId,
        'reason': reason.trim().isEmpty ? null : reason.trim(),
        'status': 'pending',
      });
      if (!mounted) return;
      setState(() => _reattemptStatus = ReattemptStatus.pending);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppException.from(e).userMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // The bubble background plays its fade-in when the result opens, as on
    // the main tabs. The navy app bar sits over it.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: AppBackground(
        introKey: widget.attemptId,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: R.headerNavy,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 64,
            leading: IconButton(
              tooltip: 'Back to tests',
              onPressed: () => context.go('/tests'),
              icon: const Icon(
                LucideIcons.chevronLeft,
                color: Colors.white,
                size: 22,
              ),
            ),
            titleSpacing: 4,
            title: const Text(
              'Result',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          body: _loading
              ? const TestResultSkeleton()
              : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : _buildContent(_bundle!),
        ),
      ),
    );
  }

  Widget _buildContent(TestResultBundle b) {
    final sections = <Widget>[
      _ScoreHero(bundle: b),
      if (b.rank.excluded)
        const _ExcludedCard()
      else if (!b.rank.released)
        _LockedRankCard(
          remaining: _remaining,
          releaseAt: b.rank.releaseAt ?? b.endsAt,
        )
      else
        _RankCard(rank: b.rank),
      _StatGrid(bundle: b),
      _ScorecardCard(bundle: b),
      _SectionCard(
        title: 'Answer Breakdown',
        child: _AnswerBreakdownChart(bundle: b),
      ),
      if (b.subjects.length > 1)
        _SectionCard(
          title: 'Subject-wise score vs max',
          outlined: true,
          child: _SubjectBarChart(subjects: b.subjects),
        ),
      _SubjectBreakdownCard(subjects: b.subjects),
      _OutlineAction(
        icon: LucideIcons.listChecks,
        label: 'View detailed response sheet',
        color: R.headerNavy,
        onPressed: () => context.push('/test-response-sheet/${b.attemptId}'),
      ),
      _ReattemptCard(
        status: _reattemptStatus,
        testId: b.testId,
        onSubmit: _submitReattemptRequest,
      ),
      Column(
        children: [
          _OutlineAction(
            label: 'Back to Tests',
            color: DS.textPrimary,
            onPressed: () => context.go('/tests'),
          ),
          const SizedBox(height: DS.s10),
          _FilledAction(
            label: 'Go to Dashboard',
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    ];

    return RefreshIndicator(
      color: DS.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(DS.s16, DS.s20, DS.s16, DS.s32),
        children: [
          for (var i = 0; i < sections.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : DS.s16),
              // Sections settle in one after another, like the main tabs.
              child: sections[i].withMotion(
                context,
                (a) => a
                    .fadeIn(
                      delay: Duration(milliseconds: 70 * (i < 6 ? i : 6)),
                      duration: 450.ms,
                      curve: Curves.easeOut,
                    )
                    .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RESULT DESIGN TOKENS (Figma result screen)
// ─────────────────────────────────────────────
abstract class R {
  static const headerNavy = Color(0xFF14307A); // app bar + score card
  static const buttonNavy = Color(0xFF1E3A8A); // primary buttons
  static const paleBlue = Color(0xFF8FA8E6); // secondary text on navy
  static const ink = Color(0xFF111111);
  static const cardBorder = Color(0xFFECECEC);
  static const correct = Color(0xFF16A34A);
  static const wrong = Color(0xFFEF3B3B);
  static const unattempted = Color(0xFF8E9DB5);
  static const scoreBar = Color(0xFFF26B1D);

  static BoxDecoration card({bool outlined = false}) => BoxDecoration(
    color: DS.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: outlined ? const Color(0xFFDADDE3) : cardBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 3)),
    ],
  );
}

// ─────────────────────────────────────────────
// SCORE HERO — navy card with verdict pill, score and three stats
// ─────────────────────────────────────────────
class _ScoreHero extends StatelessWidget {
  final TestResultBundle bundle;
  const _ScoreHero({required this.bundle});

  String get _verdict {
    final acc = bundle.accuracy;
    if (acc >= 80) return 'Excellent';
    if (acc >= 60) return 'Good';
    if (acc >= 40) return 'Keep Going';
    return 'Needs Work';
  }

  String _fmtScore(double v) => v.toStringAsFixed(1);

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final perQ = bundle.totalQuestions == 0
        ? 0
        : (bundle.timeSpentSeconds / bundle.totalQuestions).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s14, DS.s16, DS.s20),
      decoration: BoxDecoration(
        color: R.headerNavy,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3314307A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Verdict pill
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s14,
              vertical: DS.s4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.award, color: Colors.white, size: 15),
                const SizedBox(width: DS.s6),
                Text(
                  _verdict.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.s12),
          Text(
            bundle.testName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DS.s8),
          const Text(
            'Your score',
            style: TextStyle(
              color: R.paleBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: DS.s2),
          Text(
            _fmtScore(bundle.score),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          Text(
            'out of ${_fmtScore(bundle.totalMarks)}',
            style: const TextStyle(
              color: R.paleBlue,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DS.s24),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: LucideIcons.crosshair,
                  label: 'Accuracy',
                  value: '${bundle.accuracy.round()}%',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: LucideIcons.clock,
                  label: 'Time',
                  value: '${bundle.timeSpentSeconds ~/ 60}m',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: LucideIcons.trendingUp,
                  label: 'Percentile',
                  value: bundle.rank.percentile != null
                      ? bundle.rank.percentile!.toStringAsFixed(1)
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s16),
          Text(
            'Completed in ${_fmtDuration(bundle.timeSpentSeconds)} · ~${perQ}s/Q',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: R.paleBlue,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: DS.s4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: R.paleBlue,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// LOCKED RANK CARD — countdown until results release
// ─────────────────────────────────────────────
class _LockedRankCard extends StatelessWidget {
  final Duration remaining;
  final DateTime? releaseAt;

  const _LockedRankCard({required this.remaining, this.releaseAt});

  String _fmtCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  String _fmtDate(DateTime dt) {
    final local = dt.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy, $hh:$min:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s20),
      decoration: R.card(),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFE6ECF8),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.lock, color: R.headerNavy, size: 20),
          ),
          const SizedBox(height: DS.s12),
          const Text(
            'Rank & comparison unlock after the test window closes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: R.ink,
              height: 1.4,
            ),
          ),
          if (releaseAt != null) ...[
            const SizedBox(height: DS.s6),
            Text(
              'Releases on ${_fmtDate(releaseAt!)} · in ${_fmtCountdown(remaining)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: DS.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EXCLUDED CARD — shown when admin excluded this attempt from ranking
// ─────────────────────────────────────────────
class _ExcludedCard extends StatelessWidget {
  const _ExcludedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s16),
      decoration: R.card().copyWith(color: DS.warningSurface),
      child: const Row(
        children: [
          Icon(LucideIcons.info, color: DS.warning, size: 20),
          SizedBox(width: DS.s10),
          Expanded(
            child: Text(
              'This attempt has been excluded from ranking and comparison by an admin.',
              style: TextStyle(fontSize: 13, color: R.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column grid of equal-height white cards (rank + answer stats).
class _CardGrid extends StatelessWidget {
  final List<Widget> children;
  const _CardGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < children.length; r += 2) ...[
          if (r > 0) const SizedBox(height: DS.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[r]),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: r + 1 < children.length
                      ? children[r + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// RANK CARD — shown once results are released
// ─────────────────────────────────────────────
class _RankCard extends StatelessWidget {
  final RankInfo rank;
  const _RankCard({required this.rank});

  @override
  Widget build(BuildContext context) {
    final items = [
      (rank.rank != null ? '#${rank.rank}' : '—', 'Your Rank', R.headerNavy),
      ('${rank.totalAttempts ?? 0}', 'Total Attempts', DS.indigo),
      (
        rank.topperScore?.toStringAsFixed(1) ?? '—',
        'Topper Score',
        const Color(0xFF14A37F),
      ),
      (
        rank.averageScore?.toStringAsFixed(1) ?? '—',
        'Average Score',
        DS.orange,
      ),
    ];

    return _CardGrid(
      children: [
        for (final (value, label, color) in items)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s14,
              vertical: DS.s20,
            ),
            decoration: R.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: DS.s2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: R.ink,
                    height: 1.2,
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
// STAT GRID — Correct / Wrong / Unattempted / Total
// ─────────────────────────────────────────────
class _StatGrid extends StatelessWidget {
  final TestResultBundle bundle;
  const _StatGrid({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final items = [
      (LucideIcons.check, R.correct, '${bundle.correctAnswers}', 'CORRECT'),
      (LucideIcons.x, R.wrong, '${bundle.wrong}', 'WRONG'),
      (
        LucideIcons.minus,
        const Color(0xFF94A3B8),
        '${bundle.unattempted}',
        'UNATTEMPTED',
      ),
      (LucideIcons.target, DS.indigo, '${bundle.totalQuestions}', 'TOTAL'),
    ];

    return _CardGrid(
      children: [
        for (final (icon, color, value, label) in items)
          Container(
            padding: const EdgeInsets.fromLTRB(DS.s14, DS.s10, DS.s14, DS.s14),
            decoration: R.card(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filled status disc with a white glyph
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 13),
                ),
                const SizedBox(height: DS.s8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: R.ink,
                    height: 1.1,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: R.ink,
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
// SCORECARD CARD — generates and shares a printable PDF
// ─────────────────────────────────────────────
class _ScorecardCard extends StatefulWidget {
  final TestResultBundle bundle;
  const _ScorecardCard({required this.bundle});

  @override
  State<_ScorecardCard> createState() => _ScorecardCardState();
}

class _ScorecardCardState extends State<_ScorecardCard> {
  bool _generating = false;

  Future<void> _download() async {
    setState(() => _generating = true);
    try {
      final input = await buildScorecardInput(widget.bundle.attemptId);
      await generateAndShareScorecard(input);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not generate scorecard: ${AppException.from(e).userMessage}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(DS.s14, DS.s14, DS.s14, DS.s16),
      decoration: R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Scorecard',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: R.ink,
            ),
          ),
          const SizedBox(height: DS.s2),
          const Text(
            'Download a printable PDF of your performance.',
            style: TextStyle(fontSize: 13, color: R.ink, height: 1.4),
          ),
          const SizedBox(height: DS.s14),
          Center(
            child: _FilledAction(
              label: _generating ? 'Preparing…' : 'Download Scorecard PDF',
              icon: LucideIcons.download,
              busy: _generating,
              onPressed: _generating ? null : _download,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION CARD WRAPPER
// ─────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool outlined;
  const _SectionCard({
    required this.title,
    required this.child,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(DS.s20, DS.s16, DS.s20, DS.s16),
      decoration: R.card(outlined: outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: R.ink,
            ),
          ),
          const SizedBox(height: DS.s14),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ANSWER BREAKDOWN — donut chart
// ─────────────────────────────────────────────
class _AnswerBreakdownChart extends StatelessWidget {
  final TestResultBundle bundle;
  const _AnswerBreakdownChart({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final correct = bundle.correctAnswers.toDouble();
    final wrong = bundle.wrong.toDouble();
    final unattempted = bundle.unattempted.toDouble();
    final total = correct + wrong + unattempted;

    if (total == 0) {
      return const SizedBox(
        height: 160,
        child: Center(
          child: Text('No data yet', style: TextStyle(color: DS.textSecondary)),
        ),
      );
    }

    PieChartSectionData slice(double value, Color color) =>
        PieChartSectionData(value: value, color: color, title: '', radius: 52);

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sectionsSpace: 1.5,
              centerSpaceRadius: 40,
              startDegreeOffset: -2,
              sections: [
                if (correct > 0) slice(correct, R.correct),
                if (wrong > 0) slice(wrong, R.wrong),
                if (unattempted > 0) slice(unattempted, R.unattempted),
              ],
            ),
          ),
        ),
        const SizedBox(height: DS.s14),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _LegendDot(color: R.correct, label: 'CORRECT'),
            _LegendDot(color: R.wrong, label: 'WRONG'),
            _LegendDot(color: R.unattempted, label: 'UNATTEMPTED'),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: DS.s6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: R.ink,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SUBJECT-WISE BAR CHART — score vs max per subject
// ─────────────────────────────────────────────
class _SubjectBarChart extends StatelessWidget {
  final List<SubjectStat> subjects;
  const _SubjectBarChart({required this.subjects});

  @override
  Widget build(BuildContext context) {
    final maxY = subjects.fold<double>(
      1,
      (m, s) => [m, s.score, s.maxScore].reduce((a, b) => a > b ? a : b),
    );

    final interval = (maxY / 4).clamp(1, double.infinity).toDouble();
    const leftAxisWidth = 32.0;

    return Column(
      children: [
        SizedBox(
          height: 236,
          // Each subject label gets exactly its own column's width, so long
          // names ("Mathematics", "Mental Ability") never run into their
          // neighbours.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth =
                  (constraints.maxWidth - leftAxisWidth) / subjects.length;
              return BarChart(
                BarChartData(
                  maxY: maxY * 1.15,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Color(0xFFEDEDED), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFBDBDBD)),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: leftAxisWidth,
                        interval: interval,
                        getTitlesWidget: (v, meta) {
                          // Hide the padded top value (e.g. "92") — it isn't a
                          // gridline and crowds the first real label.
                          final onGrid =
                              (v / interval - (v / interval).round()).abs() <
                              1e-6;
                          if (v == meta.max && !onGrid) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            v.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: DS.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        // Room for two lines ("Mental / Ability").
                        reservedSize: 40,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= subjects.length) {
                            return const SizedBox.shrink();
                          }
                          // One word per line; a single long word shrinks just
                          // enough to fit its column instead of overlapping.
                          final label = subjects[i].subject
                              .trim()
                              .split(RegExp(r'\s+'))
                              .join('\n');
                          return Padding(
                            padding: const EdgeInsets.only(top: DS.s6),
                            child: SizedBox(
                              width: slotWidth - 4,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topCenter,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    height: 1.2,
                                    color: DS.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < subjects.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          BarChartRodData(
                            toY: subjects[i].score,
                            color: R.scoreBar,
                            width: 12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          BarChartRodData(
                            toY: subjects[i].maxScore,
                            color: R.unattempted,
                            width: 12,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: DS.s14),
        const Wrap(
          spacing: DS.s20,
          alignment: WrapAlignment.center,
          children: [
            _ChartKey(color: R.scoreBar, label: 'score'),
            _ChartKey(color: R.unattempted, label: 'max'),
          ],
        ),
      ],
    );
  }
}

/// Rounded-square key used under the bar chart.
class _ChartKey extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartKey({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: DS.s6),
      Text(
        label,
        style: const TextStyle(fontSize: 12.5, color: DS.textSecondary),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// SUBJECT-WISE BREAKDOWN — title above a white table card
// ─────────────────────────────────────────────
class _SubjectBreakdownCard extends StatelessWidget {
  final List<SubjectStat> subjects;
  const _SubjectBreakdownCard({required this.subjects});

  static const _head = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: Color(0xFF4B5563),
    letterSpacing: 0.2,
  );
  static const _cell = TextStyle(fontSize: 12.5, color: R.ink);

  @override
  Widget build(BuildContext context) {
    // Subject column gets the most room; the three numeric columns share the
    // rest equally, so the table fits the card width without scrolling.
    Widget row(List<Widget> cells, {bool divider = true}) => Container(
      padding: const EdgeInsets.symmetric(vertical: DS.s10),
      decoration: BoxDecoration(
        border: divider
            ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
            : null,
      ),
      child: Row(
        children: [
          Expanded(flex: 13, child: cells[0]),
          Expanded(flex: 10, child: Center(child: cells[1])),
          Expanded(flex: 9, child: Center(child: cells[2])),
          Expanded(flex: 9, child: Center(child: cells[3])),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: DS.s14, bottom: DS.s8),
          child: Text(
            'Subject-wise Breakdown',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: R.ink,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(DS.s10, DS.s14, DS.s10, DS.s8),
          decoration: R.card(),
          child: Column(
            children: [
              row(const [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('SUBJECT', style: _head),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('ATTEMPTED', style: _head),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('CORRECT', style: _head),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('ACCURACY', style: _head),
                ),
              ], divider: false),
              for (var i = 0; i < subjects.length; i++)
                row([
                  Text(
                    subjects[i].subject,
                    style: _cell.copyWith(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${subjects[i].attempted} / ${subjects[i].total}',
                    style: _cell,
                  ),
                  Text(
                    '${subjects[i].correct}',
                    style: _cell.copyWith(
                      color: const Color(0xFF14A37F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${subjects[i].accuracy.round()}%',
                    style: _cell.copyWith(fontWeight: FontWeight.w700),
                  ),
                ], divider: i < subjects.length - 1),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ACTION BUTTONS
// ─────────────────────────────────────────────
class _FilledAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool busy;
  final VoidCallback? onPressed;

  const _FilledAction({
    required this.label,
    this.icon,
    this.busy = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: R.buttonNavy,
            disabledBackgroundColor: R.buttonNavy.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 18),
              if (busy || icon != null) const SizedBox(width: DS.s10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback onPressed;

  const _OutlineAction({
    required this.label,
    this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: DS.surface.withValues(alpha: 0.85),
            foregroundColor: color,
            side: const BorderSide(color: Color(0xFF6B7280)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17),
                const SizedBox(width: DS.s8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RE-ATTEMPT CARD
// ─────────────────────────────────────────────
class _ReattemptCard extends StatefulWidget {
  final ReattemptStatus status;
  final String testId;
  final Future<void> Function(String reason) onSubmit;

  const _ReattemptCard({
    required this.status,
    required this.testId,
    required this.onSubmit,
  });

  @override
  State<_ReattemptCard> createState() => _ReattemptCardState();
}

class _ReattemptCardState extends State<_ReattemptCard> {
  bool _showForm = false;
  bool _submitting = false;
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await widget.onSubmit(_reasonCtrl.text);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s20),
      decoration: R.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Re-attempt this test',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: R.ink,
            ),
          ),
          const SizedBox(height: DS.s10),
          const Text(
            'Want to take this test again? Submit a request — your admin will '
            'review and approve it. Once approved, you can start a fresh '
            'attempt from the test page.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
          const SizedBox(height: DS.s20),
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    switch (widget.status) {
      case ReattemptStatus.pending:
        return const _StatusBadge(
          icon: LucideIcons.hourglass,
          color: DS.warning,
          bg: DS.warningSurface,
          label: 'Pending admin approval',
        );
      case ReattemptStatus.approved:
        return Pressable(
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.push('/test-instructions/${widget.testId}'),
              icon: const Icon(LucideIcons.circleCheck, size: 17),
              label: const Text(
                'Approved — Start fresh attempt',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        );
      case ReattemptStatus.rejected:
      case ReattemptStatus.none:
        const rejectedBadge = Padding(
          padding: EdgeInsets.only(bottom: DS.s10),
          child: _StatusBadge(
            icon: LucideIcons.circleX,
            color: DS.error,
            bg: DS.errorSurface,
            label: 'Last request rejected',
          ),
        );
        if (_showForm) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.status == ReattemptStatus.rejected) rejectedBadge,
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Reason for re-attempt (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: DS.border),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() => _showForm = false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: R.ink,
                          side: const BorderSide(color: Color(0xFF6B7280)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s10),
                  Expanded(
                    child: _FilledAction(
                      label: 'Submit Request',
                      busy: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.status == ReattemptStatus.rejected) rejectedBadge,
            _FilledAction(
              label: 'Request Re-attempt',
              icon: LucideIcons.rotateCcw,
              onPressed: () => setState(() => _showForm = true),
            ),
          ],
        );
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String label;

  const _StatusBadge({
    required this.icon,
    required this.color,
    required this.bg,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: DS.s6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(DS.s20),
        padding: const EdgeInsets.all(DS.s24),
        decoration: R.card(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: DS.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.fileText,
                color: DS.error,
                size: 30,
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'No Result Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: R.ink,
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s20),
            _FilledAction(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
