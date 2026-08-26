// Shared dashboard stat providers used by both Home and Profile.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _completedStatuses = ['submitted', 'auto_submitted'];

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
