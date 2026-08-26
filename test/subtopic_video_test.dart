import 'package:bansal/features/courses/data/models/subtopic_video.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> videoJson({
  String? subtopicLabel,
  Map<String, dynamic>? relatedSubtopic,
}) {
  return {
    'id': 'video-1',
    'course_id': 'course-1',
    'subtopic_id': 'subtopic-1',
    'topic_id': 'topic-1',
    'subtopic_label': subtopicLabel,
    'course_subtopics': relatedSubtopic,
    'title': 'Lecture 1',
  };
}

void main() {
  group('SubtopicVideo subtopic label', () {
    test('uses the label stored directly on the lecture', () {
      final video = SubtopicVideo.fromJson(
        videoJson(
          subtopicLabel: '  Thermodynamics  ',
          relatedSubtopic: {'name': 'Legacy name'},
        ),
      );

      expect(video.subtopicLabel, 'Thermodynamics');
    });

    test('falls back to the related legacy subtopic name', () {
      final video = SubtopicVideo.fromJson(
        videoJson(
          subtopicLabel: '   ',
          relatedSubtopic: {'name': '  Heat Transfer  '},
        ),
      );

      expect(video.subtopicLabel, 'Heat Transfer');
    });

    test('keeps the label null when neither source has a value', () {
      final video = SubtopicVideo.fromJson(videoJson());

      expect(video.subtopicLabel, isNull);
    });
  });
}
