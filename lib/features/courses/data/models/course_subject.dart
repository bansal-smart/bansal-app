class CourseSubject {
  final String id;
  final String courseId;
  final String name;
  final String? icon;
  final String? color;
  final int position;

  const CourseSubject({
    required this.id,
    required this.courseId,
    required this.name,
    this.icon,
    this.color,
    this.position = 0,
  });

  factory CourseSubject.fromJson(Map<String, dynamic> j) => CourseSubject(
    id: j['id'] as String,
    courseId: j['course_id'] as String,
    name: j['name'] as String? ?? '',
    icon: j['icon'] as String?,
    color: j['color'] as String?,
    position: (j['position'] as num?)?.toInt() ?? 0,
  );
}
