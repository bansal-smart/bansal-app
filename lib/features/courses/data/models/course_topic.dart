class CourseTopic {
  final String id;
  final String courseId;
  final String subjectId;
  final String name;
  final int position;

  const CourseTopic({
    required this.id,
    required this.courseId,
    required this.subjectId,
    required this.name,
    this.position = 0,
  });

  factory CourseTopic.fromJson(Map<String, dynamic> j) => CourseTopic(
        id: j['id'] as String,
        courseId: j['course_id'] as String,
        subjectId: j['subject_id'] as String,
        name: j['name'] as String? ?? '',
        position: (j['position'] as num?)?.toInt() ?? 0,
      );
}
