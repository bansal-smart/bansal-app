import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        appBar: AppBar(
          backgroundColor: DS.primary,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => context.go('/tests'),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          title: const Text(
            'Result',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: _loading
            ? const TestResultSkeleton()
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : _buildContent(_bundle!),
      ),
    );
  }

  Widget _buildContent(TestResultBundle b) {
    return RefreshIndicator(
      color: DS.primary,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s32),
        children: [
          _ScoreHero(bundle: b),
          const SizedBox(height: DS.s16),
          if (b.rank.excluded)
            const _ExcludedCard()
          else if (!b.rank.released)
            _LockedRankCard(
              remaining: _remaining,
              releaseAt: b.rank.releaseAt ?? b.endsAt,
            )
          else
            _RankCard(rank: b.rank),
          const SizedBox(height: DS.s16),
          _StatGrid(bundle: b),
          const SizedBox(height: DS.s16),
          _ScorecardCard(bundle: b),
          const SizedBox(height: DS.s16),
          _SectionCard(
            title: 'Answer breakdown',
            child: _AnswerBreakdownChart(bundle: b),
          ),
          const SizedBox(height: DS.s16),
          if (b.subjects.length > 1)
            _SectionCard(
              title: 'Subject-wise score vs max',
              child: _SubjectBarChart(subjects: b.subjects),
            ),
          if (b.subjects.length > 1) const SizedBox(height: DS.s16),
          _SubjectBreakdownCard(subjects: b.subjects),
          const SizedBox(height: DS.s16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  context.push('/test-response-sheet/${b.attemptId}'),
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('View detailed response sheet'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DS.primary,
                side: const BorderSide(color: DS.primary),
                padding: const EdgeInsets.symmetric(vertical: DS.s14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: DS.s16),
          _ReattemptCard(
            status: _reattemptStatus,
            testId: b.testId,
            onSubmit: _submitReattemptRequest,
          ),
          const SizedBox(height: DS.s16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go('/tests'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DS.textPrimary,
                side: const BorderSide(color: DS.border),
                padding: const EdgeInsets.symmetric(vertical: DS.s14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
              ),
              child: const Text('Back to Tests'),
            ),
          ),
          const SizedBox(height: DS.s10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: DS.s14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
              ),
              child: const Text('Go to Dashboard'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE HERO
// ─────────────────────────────────────────────
class _ScoreHero extends StatelessWidget {
  final TestResultBundle bundle;
  const _ScoreHero({required this.bundle});

  (String, Color) get _rankPill {
    final acc = bundle.accuracy;
    if (acc >= 80) return ('Excellent', DS.success);
    if (acc >= 60) return ('Good', DS.primary);
    if (acc >= 40) return ('Keep Going', DS.warning);
    return ('Needs Work', DS.error);
  }

  String _fmtScore(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(1) : v.toStringAsFixed(1);

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final (label, _) = _rankPill;
    final perQ = bundle.totalQuestions == 0
        ? 0
        : (bundle.timeSpentSeconds / bundle.totalQuestions).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B5BB8), DS.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s12,
              vertical: DS.s6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: DS.s6),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.s14),
          Text(
            bundle.testName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DS.s16),
          Text(
            'Your score',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: DS.s4),
          Text(
            _fmtScore(bundle.score),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          Text(
            'out of ${_fmtScore(bundle.totalMarks)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: DS.s20),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Accuracy',
                  value: '${bundle.accuracy.round()}%',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: '${bundle.timeSpentSeconds ~/ 60}m',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  icon: Icons.trending_up_rounded,
                  label: 'Percentile',
                  value: bundle.rank.percentile != null
                      ? bundle.rank.percentile!.toStringAsFixed(1)
                      : '—',
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s14),
          Text(
            'Completed in ${_fmtDuration(bundle.timeSpentSeconds)} · ~${perQ}s/Q',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
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
        Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 18),
        const SizedBox(height: DS.s6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: DS.s2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
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
      decoration: BoxDecoration(
        color: DS.surfaceVariant,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DS.surface,
              shape: BoxShape.circle,
              border: Border.all(color: DS.border),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: DS.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: DS.s12),
          const Text(
            'Rank & comparison unlock after the test window closes',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: DS.textPrimary,
              height: 1.4,
            ),
          ),
          if (releaseAt != null) ...[
            const SizedBox(height: DS.s6),
            Text(
              'Releases on ${_fmtDate(releaseAt!)} · in ${_fmtCountdown(remaining)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: DS.textSecondary),
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
      decoration: BoxDecoration(
        color: DS.warningSurface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: DS.warning, size: 20),
          const SizedBox(width: DS.s10),
          const Expanded(
            child: Text(
              'This attempt has been excluded from ranking and comparison by an admin.',
              style: TextStyle(
                fontSize: 12.5,
                color: DS.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
      ('Your Rank', rank.rank != null ? '#${rank.rank}' : '—', DS.primary),
      ('Total Attempts', '${rank.totalAttempts ?? 0}', DS.indigo),
      ('Topper Score', rank.topperScore?.toStringAsFixed(1) ?? '—', DS.success),
      (
        'Average Score',
        rank.averageScore?.toStringAsFixed(1) ?? '—',
        DS.warning,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DS.s10,
        mainAxisSpacing: DS.s10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (_, i) {
        final (label, value, color) = items[i];
        return Container(
          padding: const EdgeInsets.all(DS.s14),
          decoration: BoxDecoration(
            color: DS.surface,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            border: Border.all(color: DS.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: DS.s2),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: DS.textSecondary),
              ),
            ],
          ),
        );
      },
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
      (
        Icons.check_circle_rounded,
        DS.success,
        DS.successSurface,
        '${bundle.correctAnswers}',
        'CORRECT',
      ),
      (
        Icons.cancel_rounded,
        DS.error,
        DS.errorSurface,
        '${bundle.wrong}',
        'WRONG',
      ),
      (
        Icons.remove_circle_outline_rounded,
        DS.muted,
        DS.surfaceVariant,
        '${bundle.unattempted}',
        'UNATTEMPTED',
      ),
      (
        Icons.track_changes_rounded,
        DS.indigo,
        DS.indigoLight,
        '${bundle.totalQuestions}',
        'TOTAL',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: DS.s10,
        mainAxisSpacing: DS.s10,
        childAspectRatio: 1.7,
      ),
      itemBuilder: (_, i) {
        final (icon, color, bg, value, label) = items[i];
        return Container(
          padding: const EdgeInsets.all(DS.s14),
          decoration: BoxDecoration(
            color: DS.surface,
            borderRadius: BorderRadius.circular(DS.radiusLg),
            border: Border.all(color: DS.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(height: DS.s8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DS.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: DS.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
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
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surfaceVariant,
        borderRadius: BorderRadius.circular(DS.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Scorecard',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s4),
          const Text(
            'Download a printable PDF of your performance.',
            style: TextStyle(
              fontSize: 12,
              color: DS.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DS.s14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generating ? null : _download,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _generating ? 'Preparing…' : 'Download Scorecard PDF',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: DS.s12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
              ),
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
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s16),
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

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: [
                if (correct > 0)
                  PieChartSectionData(
                    value: correct,
                    color: DS.success,
                    title: '',
                    radius: 46,
                  ),
                if (wrong > 0)
                  PieChartSectionData(
                    value: wrong,
                    color: DS.error,
                    title: '',
                    radius: 46,
                  ),
                if (unattempted > 0)
                  PieChartSectionData(
                    value: unattempted,
                    color: DS.muted,
                    title: '',
                    radius: 46,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DS.s14),
        Wrap(
          spacing: DS.s16,
          runSpacing: DS.s8,
          alignment: WrapAlignment.center,
          children: [
            _LegendDot(color: DS.success, label: 'Correct'),
            _LegendDot(color: DS.error, label: 'Wrong'),
            _LegendDot(color: DS.muted, label: 'Unattempted'),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: DS.s6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: DS.textSecondary),
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

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.15,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY / 4).clamp(1, double.infinity),
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: DS.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
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
                    reservedSize: 32,
                    getTitlesWidget: (v, _) => Text(
                      v.toInt().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: DS.textSecondary,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= subjects.length)
                        return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: DS.s6),
                        child: Text(
                          subjects[i].subject,
                          style: const TextStyle(
                            fontSize: 10,
                            color: DS.textSecondary,
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
                    barRods: [
                      BarChartRodData(
                        toY: subjects[i].score,
                        color: DS.orange,
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: subjects[i].maxScore,
                        color: DS.muted,
                        width: 12,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: DS.s14),
        Wrap(
          spacing: DS.s16,
          alignment: WrapAlignment.center,
          children: const [
            _LegendDot(color: DS.orange, label: 'score'),
            _LegendDot(color: DS.muted, label: 'max'),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SUBJECT-WISE BREAKDOWN TABLE
// ─────────────────────────────────────────────
class _SubjectBreakdownCard extends StatelessWidget {
  final List<SubjectStat> subjects;
  const _SubjectBreakdownCard({required this.subjects});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            'Subject-wise Breakdown',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 32,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 44,
              horizontalMargin: 0,
              columnSpacing: DS.s20,
              headingTextStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: DS.textSecondary,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 12.5,
                color: DS.textPrimary,
              ),
              columns: const [
                DataColumn(label: Text('Subject')),
                DataColumn(label: Text('Attempted')),
                DataColumn(label: Text('Correct')),
                DataColumn(label: Text('Accuracy')),
                DataColumn(label: Text('Score')),
              ],
              rows: subjects
                  .map(
                    (s) => DataRow(
                      cells: [
                        DataCell(
                          Text(
                            s.subject,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        DataCell(Text('${s.attempted}/${s.total}')),
                        DataCell(
                          Text(
                            '${s.correct}',
                            style: const TextStyle(
                              color: DS.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        DataCell(Text('${s.accuracy.round()}%')),
                        DataCell(
                          Text(
                            '${s.score.toStringAsFixed(1)} / ${s.maxScore.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
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
            'Re-attempt this test',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s6),
          const Text(
            'Want to take this test again? Submit a request — your admin will '
            'review and approve it. Once approved, you can start a fresh '
            'attempt from the test page.',
            style: TextStyle(
              fontSize: 12.5,
              color: DS.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DS.s14),
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    switch (widget.status) {
      case ReattemptStatus.pending:
        return _StatusBadge(
          icon: Icons.hourglass_top_rounded,
          color: DS.warning,
          bg: DS.warningSurface,
          label: 'Pending admin approval',
        );
      case ReattemptStatus.approved:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                context.push('/test-instructions/${widget.testId}'),
            icon: const Icon(Icons.check_circle_rounded, size: 16),
            label: const Text('Approved — Start fresh attempt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: DS.success,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: DS.s12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
            ),
          ),
        );
      case ReattemptStatus.rejected:
      case ReattemptStatus.none:
        if (_showForm) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.status == ReattemptStatus.rejected)
                const Padding(
                  padding: EdgeInsets.only(bottom: DS.s10),
                  child: _StatusBadge(
                    icon: Icons.cancel_rounded,
                    color: DS.error,
                    bg: DS.errorSurface,
                    label: 'Last request rejected',
                  ),
                ),
              TextField(
                controller: _reasonCtrl,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Reason for re-attempt (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                    borderSide: const BorderSide(color: DS.border),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _showForm = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DS.textPrimary,
                        side: const BorderSide(color: DS.border),
                        padding: const EdgeInsets.symmetric(vertical: DS.s12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: DS.s10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DS.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: DS.s12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit Request'),
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
            if (widget.status == ReattemptStatus.rejected)
              const Padding(
                padding: EdgeInsets.only(bottom: DS.s10),
                child: _StatusBadge(
                  icon: Icons.cancel_rounded,
                  color: DS.error,
                  bg: DS.errorSurface,
                  label: 'Last request rejected',
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _showForm = true),
                icon: const Icon(Icons.replay_rounded, size: 16),
                label: const Text('Request Re-attempt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: DS.s12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                ),
              ),
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
              fontSize: 12,
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
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: const Icon(
                Icons.assignment_late_outlined,
                color: DS.error,
                size: 36,
              ),
            ),
            const SizedBox(height: DS.s20),
            const Text(
              'No Result Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
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
