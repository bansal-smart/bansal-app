import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/enrollment.dart';

class EnrollmentsRepository {
  final SupabaseClient _client;

  EnrollmentsRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  /// Auto-enrolls the student in every free (price = 0) published course that
  /// matches their target exam. Safe to call multiple times — duplicates are
  /// ignored. `userClass` is accepted for call-site compatibility but is no
  /// longer used for filtering — there is no class column on `courses`.
  Future<void> autoEnrollFreeCourses({
    required String exam,
    required String userClass,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || exam.isEmpty) return;

      // Accept both current web profile values and legacy course values.
      final targetExams = switch (exam) {
        'IIT-JEE' => const ['IIT-JEE', 'JEE'],
        'Pre Foundation' || 'Pre-Foundation' => const [
          'Pre Foundation',
          'Pre-Foundation',
          'Foundation',
        ],
        _ => [exam],
      };

      // Fetch all free published courses for this target exam.
      final query = _client
          .from('courses')
          .select('id, target_exam, price')
          .eq('price', 0)
          .eq('is_published', true)
          .inFilter('target_exam', targetExams);

      final rows = await query as List<dynamic>;
      if (rows.isEmpty) return;

      final records = rows
          .map(
            (r) => {
              'user_id': userId,
              'course_id': (r as Map<String, dynamic>)['id'] as String,
              'is_active': true,
              'progress_percent': 0,
            },
          )
          .toList();

      await _client
          .from('enrollments')
          .upsert(
            records,
            onConflict: 'user_id,course_id',
            ignoreDuplicates: true,
          );
    } catch (e) {
      // Non-fatal — log and continue
      debugPrint('[AutoEnroll] error: $e');
    }
  }

  Future<void> enrollInCourse(String courseId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const UnauthorizedException();
      // Use insert with ignoreDuplicates — more reliable than upsert with RLS
      await _client.from('enrollments').insert({
        'user_id': userId,
        'course_id': courseId,
        'is_active': true,
        'progress_percent': 0,
      });
    } on PostgrestException catch (e) {
      // Duplicate key (already enrolled) — not an error
      if (e.code == '23505') return;
      throw AppException.from(e);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> touchLastAccessed(String courseId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      await _client
          .from('enrollments')
          .update({'last_accessed_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .eq('course_id', courseId);
    } catch (e) {
      debugPrint('[Enrollments] touchLastAccessed error: $e');
    }
  }

  Future<List<Enrollment>> fetchMyEnrollments() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];
      final nowIso = DateTime.now().toIso8601String();
      final data = await _client
          .from('enrollments')
          .select(
            'id, user_id, course_id, progress_percent, '
            'last_accessed_at, is_active, created_at, expires_at, '
            'courses!inner(name, subject, target_exam, thumbnail_url, '
            'educator_name, is_published)',
          )
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('courses.is_published', true)
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .order('last_accessed_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => Enrollment.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
