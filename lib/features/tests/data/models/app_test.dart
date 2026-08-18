class AppTest {
  final String id;
  final String title;
  final String? slug;
  final String? description;
  final String testType;
  final String examPattern;
  final List<String> subjects;
  final int durationMinutes;
  final double totalMarks;
  final int totalQuestions;
  final String visibility;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? courseId;
  final List<String> cbtAllowedBatchIds;
  final String testMode;
  final DateTime? resultsReleasedAt;

  const AppTest({
    required this.id,
    required this.title,
    this.slug,
    this.description,
    required this.testType,
    required this.examPattern,
    required this.subjects,
    required this.durationMinutes,
    required this.totalMarks,
    required this.totalQuestions,
    required this.visibility,
    this.startsAt,
    this.endsAt,
    this.courseId,
    this.cbtAllowedBatchIds = const [],
    this.testMode = 'digital',
    this.resultsReleasedAt,
  });

  String get subject => subjects.isNotEmpty ? subjects.first : examPattern;
  bool get isCbt => testMode == 'cbt';

  factory AppTest.fromJson(Map<String, dynamic> json) => AppTest(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    slug: json['slug'] as String?,
    description: json['description'] as String?,
    testType: json['test_type'] as String? ?? '',
    examPattern: json['exam_pattern'] as String? ?? '',
    subjects: (json['subjects'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        [],
    durationMinutes: json['duration_minutes'] as int? ?? 0,
    totalMarks: _toDouble(json['total_marks']),
    totalQuestions: json['total_questions'] as int? ?? 0,
    visibility: json['visibility'] as String? ?? 'public',
    startsAt: json['starts_at'] != null
        ? DateTime.parse(json['starts_at'] as String)
        : null,
    endsAt: json['ends_at'] != null
        ? DateTime.parse(json['ends_at'] as String)
        : null,
    courseId: json['course_id'] as String?,
    cbtAllowedBatchIds: (json['cbt_allowed_batch_ids'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        const [],
    testMode: json['test_mode'] as String? ?? 'digital',
    resultsReleasedAt: json['results_released_at'] != null
        ? DateTime.parse(json['results_released_at'] as String)
        : null,
  );

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
