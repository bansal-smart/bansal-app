import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/course.dart';

class CoursesRepository {
  final SupabaseClient _client;

  CoursesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  static const _courseColumns =
      'id, slug, name, description, subject, educator_name, level, target_exam, '
      'thumbnail_url, price, original_price, discount_percent, rating, '
      'total_enrolled, total_lessons, duration_hours, tags, badge, '
      'is_featured, is_published, what_youll_learn, requirements, sort_order, '
      'short_description, education_level, duration_label, mode, language, '
      'subjects_covered, description_html, included_services, centre_id, '
      'is_global, end_date';

  Future<List<Course>> fetchCourses() async {
    try {
      final data = await _client
          .from('courses')
          .select(_courseColumns)
          .eq('is_published', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((row) => Course.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
