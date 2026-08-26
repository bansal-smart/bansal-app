class SubtopicVideo {
  final String id;
  final String courseId;
  final String? subtopicId;
  final String topicId;
  final String? subtopicLabel;
  final String title;
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final String? thumbnailUrl;
  final String? durationLabel;
  final String? description;
  final int position;
  final bool isPreview;

  const SubtopicVideo({
    required this.id,
    required this.courseId,
    this.subtopicId,
    required this.topicId,
    this.subtopicLabel,
    required this.title,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.thumbnailUrl,
    this.durationLabel,
    this.description,
    this.position = 0,
    this.isPreview = false,
  });

  factory SubtopicVideo.fromJson(Map<String, dynamic> j) {
    final storedLabel = (j['subtopic_label'] as String?)?.trim();
    final relatedSubtopic = j['course_subtopics'];
    final relatedLabel = relatedSubtopic is Map
        ? (relatedSubtopic['name'] as String?)?.trim()
        : null;

    return SubtopicVideo(
      id: j['id'] as String,
      courseId: j['course_id'] as String,
      subtopicId: j['subtopic_id'] as String?,
      topicId: j['topic_id'] as String,
      subtopicLabel: storedLabel?.isNotEmpty == true
          ? storedLabel
          : relatedLabel,
      title: j['title'] as String? ?? '',
      youtubeUrl: j['youtube_url'] as String?,
      youtubeVideoId: j['youtube_video_id'] as String?,
      thumbnailUrl: j['thumbnail_url'] as String?,
      durationLabel: j['duration_label'] as String?,
      description: j['description'] as String?,
      position: (j['position'] as num?)?.toInt() ?? 0,
      isPreview: j['is_preview'] as bool? ?? false,
    );
  }
}
