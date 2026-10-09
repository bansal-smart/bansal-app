class Enrollment {
  final String id;
  final String userId;
  final String courseId;
  final int progressPercent;
  final DateTime? lastAccessedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? expiresAt;

  // Joined course fields
  final String? courseTitle;
  final String? courseSubject;
  final String? courseThumbnailUrl;
  final String? courseEducatorName;
  final bool courseIsActive;

  const Enrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.progressPercent,
    this.lastAccessedAt,
    required this.isActive,
    required this.createdAt,
    this.expiresAt,
    this.courseTitle,
    this.courseSubject,
    this.courseThumbnailUrl,
    this.courseEducatorName,
    this.courseIsActive = true,
  });

  double get progressFraction => progressPercent / 100.0;

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    // PostgREST returns a many-to-one join as either a Map or a single-element
    // List depending on the relationship definition. Handle both.
    final raw = json['courses'];
    final course = raw is Map<String, dynamic>
        ? raw
        : (raw is List && raw.isNotEmpty)
        ? raw.first as Map<String, dynamic>?
        : null;
    return Enrollment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      progressPercent: json['progress_percent'] as int? ?? 0,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      courseTitle: course?['name'] as String?,
      courseSubject: course?['subject'] as String?,
      courseThumbnailUrl: course?['thumbnail_url'] as String?,
      courseEducatorName: course?['educator_name'] as String?,
      courseIsActive: course?['is_published'] as bool? ?? true,
    );
  }
}
