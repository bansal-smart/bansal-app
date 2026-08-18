// Shared dashboard stat providers used by both the Home screen and the
// Profile screen, so both surfaces show identical numbers computed the
// same way. These are the canonical implementations — do not duplicate
// this logic elsewhere.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Total number of test attempts the student has completed.
final testsCompletedProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 0;
  final data = await client
      .from('test_attempts')
      .select('id')
      .eq('user_id', userId);
  return (data as List).length;
});

/// Consecutive days of study activity, via the same `get_user_streak` RPC
/// the web dashboard uses (counts consecutive `study_sessions` rows).
final streakProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return 0;
  final result = await client.rpc(
    'get_user_streak',
    params: {'_user_id': userId},
  );
  return (result as num?)?.toInt() ?? 0;
});

/// Overall accuracy across all of the student's test attempts:
/// sum(correct_answers) / sum(total_questions), as a whole-number percent.
/// (The web dashboard's own accuracy tile reads study_sessions columns that
/// are never populated by any code path, so it always shows "—" there too —
/// this uses test_attempts instead, which has real per-attempt data.)
final accuracyProvider = FutureProvider.autoDispose<int?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await client
      .from('test_attempts')
      .select('correct_answers, total_questions')
      .eq('user_id', userId);
  final rows = data as List;
  var correct = 0;
  var total = 0;
  for (final r in rows) {
    final row = r as Map<String, dynamic>;
    correct += (row['correct_answers'] as int?) ?? 0;
    total += (row['total_questions'] as int?) ?? 0;
  }
  if (total == 0) return null;
  return ((correct / total) * 100).round();
});

/// Average percentile across the student's 5 most recent test attempts —
/// mirrors the web dashboard's "AIR Percentile" tile exactly (each
/// `percentile` value is a point-in-time snapshot taken at submit time).
final airPercentileProvider = FutureProvider.autoDispose<double?>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await client
      .from('test_attempts')
      .select('percentile, attempted_at')
      .eq('user_id', userId)
      .not('percentile', 'is', null)
      .order('attempted_at', ascending: false)
      .limit(5);
  final rows = data as List;
  if (rows.isEmpty) return null;
  final sum = rows.fold<double>(
    0,
    (s, r) => s + (((r as Map<String, dynamic>)['percentile'] as num).toDouble()),
  );
  return ((sum / rows.length) * 10).round() / 10;
});
