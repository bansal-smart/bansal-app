import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/enrollment.dart';

class EnrollmentsRepository {
  final SupabaseClient _client;

  EnrollmentsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  /// Auto-enrolls the student in every free course that matches their
  /// target exam and class. Safe to call multiple times — duplicates are ignored.
  Future<void> autoEnrollFreeCourses({
    required String exam,
    required String userClass,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null || exam.isEmpty) return;

      // Normalise class: prefs stores '8th'/'9th'/'10th', DB stores '8'/'9'/'10'
      final dbClass = userClass
          .replaceAll('th', '')
          .replaceAll('st', '')
          .replaceAll('nd', '')
          .replaceAll('rd', '');

      // Fetch all free active courses for this exam
      var query = _client
          .from('courses')
          .select('id, target, class')
          .eq('is_course_free', true)
          .eq('is_active', true)
          .eq('target', exam);

      // Foundation students only get courses for their specific class
      if (exam == 'Foundation' && dbClass.isNotEmpty) {
        query = query.eq('class', dbClass);
      }

      final rows = await query as List<dynamic>;
      if (rows.isEmpty) return;

      final records = rows
          .map((r) => {
                'user_id': userId,
                'course_id': (r as Map<String, dynamic>)['id'] as String,
                'is_active': true,
                'progress_percent': 0,
              })
          .toList();

      await _client
          .from('enrollments')
          .upsert(records, onConflict: 'user_id,course_id', ignoreDuplicates: true);
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
      final data = await _client
          .from('enrollments')
          .select(
            'id, user_id, course_id, progress_percent, '
            'last_accessed_at, is_active, created_at, '
            'courses!inner(name, target, thumbnail_url, is_active)',
          )
          .eq('user_id', userId)
          .eq('is_active', true)
          .eq('courses.is_active', true)
          .order('last_accessed_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => Enrollment.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
