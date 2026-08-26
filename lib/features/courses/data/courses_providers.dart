import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/config/env.dart';
import 'models/course.dart';
import 'models/course_subject.dart';
import 'models/course_topic.dart';
import 'models/subtopic_pdf.dart';
import 'models/subtopic_video.dart';
import 'repositories/courses_repository.dart';

// ── Video URL resolution (unchanged) ──────────────────────────────────────
Future<String?> resolveVideoUrl(String rawPath) async {
  if (rawPath.startsWith('http')) return rawPath;
  final s3Base = Env.s3VideoBaseUrl;
  if (s3Base.isNotEmpty) return '$s3Base/$rawPath';
  try {
    return await SupabaseService.client.storage
        .from('course-resources')
        .createSignedUrl(rawPath, 3600);
  } catch (_) {}
  return null;
}

const _courseColumns =
    'id, slug, name, description, subject, educator_name, level, target_exam, '
    'thumbnail_url, price, original_price, discount_percent, rating, '
    'total_enrolled, total_lessons, duration_hours, tags, badge, '
    'is_featured, is_published, what_youll_learn, requirements, sort_order, '
    'short_description, education_level, duration_label, mode, language, '
    'subjects_covered, description_html, included_services, centre_id, '
    'is_global, end_date';

// ── Repository provider ────────────────────────────────────────────────────
final coursesRepositoryProvider = Provider<CoursesRepository>(
  (_) => CoursesRepository(),
);

// ── Course store list (Screen 1) ───────────────────────────────────────────
final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) =>
    ref.watch(coursesRepositoryProvider).fetchCourses());

// ── Single course detail by id ─────────────────────────────────────────────
final courseDetailProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, id) async {
  final data = await SupabaseService.client
      .from('courses')
      .select(_courseColumns)
      .eq('id', id)
      .single();
  return Course.fromJson(data);
});

// ── Single course detail by slug ───────────────────────────────────────────
final courseBySlugProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, slug) async {
  final data = await SupabaseService.client
      .from('courses')
      .select(_courseColumns)
      .eq('slug', slug)
      .single();
  return Course.fromJson(data);
});

// ── Subjects within a course ───────────────────────────────────────────────
final courseSubjectsProvider =
    FutureProvider.autoDispose.family<List<CourseSubject>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('course_subjects')
      .select('id, course_id, name, icon, color, position')
      .eq('course_id', courseId)
      .order('position', ascending: true);
  return (data as List<dynamic>)
      .map((r) => CourseSubject.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Topics within a subject ────────────────────────────────────────────────
final courseTopicsProvider =
    FutureProvider.autoDispose.family<List<CourseTopic>, String>(
        (ref, subjectId) async {
  final data = await SupabaseService.client
      .from('course_topics')
      .select('id, course_id, subject_id, name, position')
      .eq('subject_id', subjectId)
      .order('position', ascending: true);
  return (data as List<dynamic>)
      .map((r) => CourseTopic.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Videos within a topic ──────────────────────────────────────────────────
final topicVideosProvider =
    FutureProvider.autoDispose.family<List<SubtopicVideo>, String>(
        (ref, topicId) async {
  final data = await SupabaseService.client
      .from('subtopic_videos')
      .select(
        'id, course_id, subtopic_id, topic_id, subtopic_label, title, '
        'youtube_url, youtube_video_id, thumbnail_url, duration_label, '
        'description, position, is_preview, '
        'course_subtopics!subtopic_videos_subtopic_id_fkey(name)',
      )
      .eq('topic_id', topicId)
      .order('position', ascending: true);
  return (data as List<dynamic>)
      .map((r) => SubtopicVideo.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── PDFs within a topic ────────────────────────────────────────────────────
final topicPdfsProvider =
    FutureProvider.autoDispose.family<List<SubtopicPdf>, String>(
        (ref, topicId) async {
  final data = await SupabaseService.client
      .from('subtopic_pdfs')
      .select(
        'id, course_id, subtopic_id, topic_id, subtopic_label, title, '
        'file_url, file_size_kb, position',
      )
      .eq('topic_id', topicId)
      .order('position', ascending: true);
  return (data as List<dynamic>)
      .map((r) => SubtopicPdf.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Free-preview videos for a whole course (used on Course Detail screen) ──
final courseFreePreviewVideosProvider =
    FutureProvider.autoDispose.family<List<SubtopicVideo>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('subtopic_videos')
      .select(
        'id, course_id, subtopic_id, topic_id, subtopic_label, title, '
        'youtube_url, youtube_video_id, thumbnail_url, duration_label, '
        'description, position, is_preview, '
        'course_subtopics!subtopic_videos_subtopic_id_fkey(name)',
      )
      .eq('course_id', courseId)
      .eq('is_preview', true)
      .order('position', ascending: true);
  return (data as List<dynamic>)
      .map((r) => SubtopicVideo.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── All PDFs for a whole course (used on Course Detail screen) ────────────
final coursePdfsProvider =
    FutureProvider.autoDispose.family<List<SubtopicPdf>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('subtopic_pdfs')
      .select(
        'id, course_id, subtopic_id, topic_id, subtopic_label, title, '
        'file_url, file_size_kb, position',
      )
      .eq('course_id', courseId)
      .order('position', ascending: true);
  return (data as List<dynamic>)
      .map((r) => SubtopicPdf.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Per-user video progress for a course — set of completed video IDs ─────
final videoProgressProvider =
    FutureProvider.autoDispose.family<Set<String>, String>(
        (ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return <String>{};
  final data = await SupabaseService.client
      .from('subtopic_video_progress')
      .select('video_id, is_completed')
      .eq('user_id', userId)
      .eq('course_id', courseId);
  return (data as List<dynamic>)
      .where((r) => (r as Map<String, dynamic>)['is_completed'] == true)
      .map((r) => (r as Map<String, dynamic>)['video_id'] as String)
      .toSet();
});

/// Upserts a student's watch progress for a single video.
Future<void> markVideoProgress({
  required String videoId,
  String? subtopicId,
  required String courseId,
  bool isCompleted = true,
  int? watchTimeSeconds,
}) async {
  final client = SupabaseService.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return;

  final existing = await client
      .from('subtopic_video_progress')
      .select('id')
      .eq('user_id', userId)
      .eq('video_id', videoId)
      .maybeSingle();

  final payload = {
    'user_id': userId,
    'video_id': videoId,
    if (subtopicId != null) 'subtopic_id': subtopicId,
    'course_id': courseId,
    'is_completed': isCompleted,
    if (watchTimeSeconds != null) 'watch_time_seconds': watchTimeSeconds,
    'last_accessed_at': DateTime.now().toIso8601String(),
  };

  if (existing != null) {
    await client
        .from('subtopic_video_progress')
        .update(payload)
        .eq('id', existing['id'] as String);
  } else {
    await client.from('subtopic_video_progress').insert(payload);
  }

  final now = DateTime.now();
  final date =
      '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  await client.from('study_sessions').upsert({
    'user_id': userId,
    'session_date': date,
  }, onConflict: 'user_id,session_date', ignoreDuplicates: true);
}

// ── Enrollment with enrolled_at (for free-course expiry check) ────────────
class EnrollmentInfo {
  final String courseId;
  final DateTime enrolledAt;
  const EnrollmentInfo({required this.courseId, required this.enrolledAt});
}

final enrollmentInfoProvider =
    FutureProvider.autoDispose.family<EnrollmentInfo?, String>(
        (ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await SupabaseService.client
      .from('enrollments')
      .select('course_id, created_at')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .maybeSingle();
  if (data == null) return null;
  return EnrollmentInfo(
    courseId: data['course_id'] as String,
    enrolledAt: DateTime.parse(data['created_at'] as String),
  );
});

// ── Reviews ────────────────────────────────────────────────────────────────
class CourseReview {
  final String id;
  final int rating;
  final String? review;
  final DateTime createdAt;
  const CourseReview({
    required this.id,
    required this.rating,
    this.review,
    required this.createdAt,
  });
  factory CourseReview.fromJson(Map<String, dynamic> j) => CourseReview(
        id: j['id'] as String,
        rating: (j['rating'] as num).toInt(),
        review: j['review'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

final courseReviewsProvider =
    FutureProvider.autoDispose.family<List<CourseReview>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('course_reviews')
      .select('id, rating, review, created_at')
      .eq('course_id', courseId)
      .order('created_at', ascending: false);
  return (data as List<dynamic>)
      .map((r) => CourseReview.fromJson(r as Map<String, dynamic>))
      .toList();
});

final myReviewProvider =
    FutureProvider.autoDispose.family<CourseReview?, String>(
        (ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await SupabaseService.client
      .from('course_reviews')
      .select('id, rating, review, created_at')
      .eq('course_id', courseId)
      .eq('user_id', userId)
      .maybeSingle();
  if (data == null) return null;
  return CourseReview.fromJson(data);
});

final courseEnrolledCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, courseId) async {
  final data = await SupabaseService.client
      .from('enrollments')
      .select('id')
      .eq('course_id', courseId)
      .eq('is_active', true);
  return (data as List<dynamic>).length;
});

final isEnrolledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return false;
  final data = await SupabaseService.client
      .from('enrollments')
      .select('id')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .eq('is_active', true)
      .maybeSingle();
  return data != null;
});
