// Shared dashboard stat providers used by both Home and Profile.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _completedStatuses = ['submitted', 'auto_submitted'];

class TestReportSummary {
  final String attemptId;
  final String title;
  final double score;
  final double totalMarks;
  final int correct;
  final int wrong;
  final int unattempted;
  final DateTime? submittedAt;
  final bool released;

  const TestReportSummary({
    required this.attemptId,
    required this.title,
    required this.score,
    required this.totalMarks,
    required this.correct,
    required this.wrong,
    required this.unattempted,
    required this.submittedAt,
    required this.released,
  });
}

/// Completed attempts are fetched independently of the active test catalogue,
/// so closing or unpublishing an exam cannot remove its historical report.
final testReportHistoryProvider =
    FutureProvider.autoDispose<List<TestReportSummary>>((ref) async {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return const [];
      final data = await client
          .from('test_attempts')
          .select(
            'id,test_name,score,total_questions,correct_answers,submitted_at,attempted_at,metadata',
          )
          .eq('user_id', userId)
          .inFilter('status', _completedStatuses)
          .order('submitted_at', ascending: false)
          .limit(20);

      final reports = <TestReportSummary>[];
      for (final raw in data as List) {
        final row = Map<String, dynamic>.from(raw as Map);
        final metadata = row['metadata'] as Map?;
        final metaQuestions = metadata?['questions'] as List? ?? const [];
        final attempted =
            (metadata?['attempted'] as num?)?.toInt() ??
            metaQuestions
                .where((q) => q is Map && q['attempted'] == true)
                .length;
        final total =
            (row['total_questions'] as num?)?.toInt() ?? metaQuestions.length;
        final correct = (row['correct_answers'] as num?)?.toInt() ?? 0;
        final maxMarks = metaQuestions.fold<double>(
          0,
          (sum, q) =>
              sum +
              ((q is Map ? q['max_marks'] : null) as num? ?? 0).toDouble(),
        );
        var released = false;
        try {
          final rank = await client.rpc(
            'get_test_rank',
            params: {'_attempt_id': row['id']},
          );
          released = rank is Map && rank['released'] == true;
        } catch (_) {
          // Older installations may not expose ranking; the result screen will
          // still enforce its own release state when opened.
        }
        reports.add(
          TestReportSummary(
            attemptId: row['id'] as String,
            title: row['test_name'] as String? ?? 'Test',
            score: (row['score'] as num?)?.toDouble() ?? 0,
            totalMarks: maxMarks,
            correct: correct,
            wrong: (attempted - correct).clamp(0, total),
            unattempted: (total - attempted).clamp(0, total),
            submittedAt: DateTime.tryParse(
              (row['submitted_at'] ?? row['attempted_at'] ?? '').toString(),
            ),
            released: released,
          ),
        );
      }
      return reports;
    });

/// Total number of test attempts the student has actually completed.
final testsCompletedProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 0;

  final data = await client
      .from('test_attempts')
      .select('id')
      .eq('user_id', userId)
      .inFilter('status', _completedStatuses);
  return (data as List).length;
});

/// Consecutive local calendar days containing real learning activity.
///
/// A day counts when the student watches a lesson, submits a test, joins a
/// live class, or has a study_sessions entry. Yesterday's streak remains
/// visible until the current day is over.
final streakProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 0;

  final activityDays = <DateTime>[];

  Future<void> collect(
    Future<dynamic> request,
    String field, {
    bool dateOnly = false,
  }) async {
    try {
      final rows = await request as List;
      for (final item in rows) {
        final row = item as Map<String, dynamic>;
        final value = row[field]?.toString();
        if (value == null || value.isEmpty) continue;
        final parsed = DateTime.tryParse(value);
        if (parsed == null) continue;
        activityDays.add(
          dateOnly
              ? DateTime(parsed.year, parsed.month, parsed.day)
              : parsed.toLocal(),
        );
      }
    } catch (_) {
      // An optional activity source must not hide all other progress.
    }
  }

  await Future.wait([
    collect(
      client
          .from('study_sessions')
          .select('session_date')
          .eq('user_id', userId),
      'session_date',
      dateOnly: true,
    ),
    collect(
      client
          .from('test_attempts')
          .select('attempted_at')
          .eq('user_id', userId)
          .inFilter('status', _completedStatuses),
      'attempted_at',
    ),
    collect(
      client
          .from('lesson_progress')
          .select('last_watched_at')
          .eq('user_id', userId)
          .not('last_watched_at', 'is', null),
      'last_watched_at',
    ),
    collect(
      client
          .from('subtopic_video_progress')
          .select('last_accessed_at')
          .eq('user_id', userId)
          .not('last_accessed_at', 'is', null),
      'last_accessed_at',
    ),
    collect(
      client
          .from('live_class_attendance')
          .select('joined_at')
          .eq('user_id', userId)
          .not('joined_at', 'is', null),
      'joined_at',
    ),
  ]);

  return calculateActivityStreak(activityDays, DateTime.now());
});

/// Overall accuracy across completed tests, using questions actually
/// attempted as the denominator (the same definition as TestResultScreen).
final accuracyProvider = FutureProvider.autoDispose<int?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final data = await client
      .from('test_attempts')
      .select('correct_answers,total_questions,metadata')
      .eq('user_id', userId)
      .inFilter('status', _completedStatuses);
  return calculateOverallAccuracy(
    (data as List).map((row) => Map<String, dynamic>.from(row as Map)).toList(),
  );
});

/// The most recent released test's current leaderboard percentile.
/// `get_test_rank` refreshes the leaderboard cache, so this stays accurate as
/// more students submit instead of averaging old submission-time snapshots.
final airPercentileProvider = FutureProvider.autoDispose<double?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final data = await client
      .from('test_attempts')
      .select('id,percentile,attempted_at')
      .eq('user_id', userId)
      .inFilter('status', _completedStatuses)
      .order('attempted_at', ascending: false)
      .limit(5);
  final rows = (data as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  for (final row in rows) {
    try {
      final rank = await client.rpc(
        'get_test_rank',
        params: {'_attempt_id': row['id']},
      );
      if (rank is Map && rank['released'] == true) {
        final percentile = rank['percentile'] as num?;
        if (percentile != null) return percentile.toDouble();
      }
    } catch (_) {
      // Fall through to the stored snapshot for older backend versions.
    }
  }

  for (final row in rows) {
    final stored = row['percentile'] as num?;
    if (stored != null) return stored.toDouble();
  }
  return null;
});

/// Pure calculation kept public so date-boundary behaviour can be tested.
int calculateActivityStreak(Iterable<DateTime> activityDates, DateTime now) {
  final days = activityDates
      .map((date) => DateTime(date.year, date.month, date.day))
      .toSet();
  if (days.isEmpty) return 0;

  final today = DateTime(now.year, now.month, now.day);
  var cursor = days.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  if (!days.contains(cursor)) return 0;

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Pure aggregate matching the per-test accuracy shown on result screens.
int? calculateOverallAccuracy(List<Map<String, dynamic>> attempts) {
  var correct = 0;
  var attempted = 0;

  for (final row in attempts) {
    final rowCorrect = (row['correct_answers'] as num?)?.toInt() ?? 0;
    final metadata = row['metadata'] as Map?;
    final metadataAttempted = (metadata?['attempted'] as num?)?.toInt();
    final fallbackTotal = (row['total_questions'] as num?)?.toInt() ?? 0;

    correct += rowCorrect;
    attempted += metadataAttempted ?? fallbackTotal;
  }

  if (attempted <= 0) return null;
  return ((correct / attempted) * 100).round().clamp(0, 100);
}
