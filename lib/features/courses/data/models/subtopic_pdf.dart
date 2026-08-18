class SubtopicPdf {
  final String id;
  final String courseId;
  final String? subtopicId;
  final String topicId;
  final String? subtopicLabel;
  final String title;
  final String? fileUrl;
  final int? fileSizeKb;
  final int position;

  const SubtopicPdf({
    required this.id,
    required this.courseId,
    this.subtopicId,
    required this.topicId,
    this.subtopicLabel,
    required this.title,
    this.fileUrl,
    this.fileSizeKb,
    this.position = 0,
  });

  factory SubtopicPdf.fromJson(Map<String, dynamic> j) => SubtopicPdf(
        id: j['id'] as String,
        courseId: j['course_id'] as String,
        subtopicId: j['subtopic_id'] as String?,
        topicId: j['topic_id'] as String,
        subtopicLabel: j['subtopic_label'] as String?,
        title: j['title'] as String? ?? '',
        fileUrl: j['file_url'] as String?,
        fileSizeKb: (j['file_size_kb'] as num?)?.toInt(),
        position: (j['position'] as num?)?.toInt() ?? 0,
      );
}
