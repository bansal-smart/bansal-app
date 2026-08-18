import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/app_test.dart';
import '../models/test_attempt.dart';

const testSelectColumns =
    'id, title, slug, description, test_type, exam_pattern, subjects, '
    'duration_minutes, total_marks, total_questions, visibility, '
    'starts_at, ends_at, course_id, cbt_allowed_batch_ids, test_mode, '
    'results_released_at';

class TestsRepository {
  final SupabaseClient _client;

  TestsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  Future<List<AppTest>> fetchPublished() async {
    try {
      final data = await _client
          .from('tests')
          .select(testSelectColumns)
          .eq('is_published', true)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((row) => AppTest.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<TestAttempt>> fetchMyAttempts() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _client
          .from('test_attempts')
          .select('id, test_id, status')
          .eq('user_id', userId);
      return (data as List<dynamic>)
          .map((row) => TestAttempt.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Set<String>> fetchMyAssignedTestIds() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {};
      final data = await _client
          .from('test_assignments')
          .select('test_id')
          .eq('user_id', userId)
          .eq('is_active', true);
      return (data as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['test_id'] as String)
          .toSet();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<String?> fetchMyBatchId() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;
      final data = await _client
          .from('profiles')
          .select('batch_id')
          .eq('user_id', userId)
          .maybeSingle();
      return data?['batch_id'] as String?;
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
