import 'package:bansal/features/tests/test_engine_screen.dart';
import 'package:bansal/features/tests/test_response_sheet_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'test question keeps configured subject and per-question marking',
    () async {
      final question = await TestQuestion.fromJson({
        'id': 'q1',
        'question_text': 'Sample question',
        'options': ['One', 'Two'],
        'correct_answer': 1,
        'question_type': 'mcq',
        'subject': 'Physics',
        'marks_correct': 3,
        'marks_wrong': -0.5,
      });

      expect(question.subject, 'Physics');
      expect(question.marksCorrect, 3);
      expect(question.marksWrong, -0.5);
    },
  );

  test(
    'response question accepts string options and numerical answers',
    () async {
      final question = await ResponseQuestion.fromJson(
        {
          'id': 'q2',
          'position': 4,
          'question_text': 'Enter the value',
          'options': <String>[],
          'selected': '-2.5',
          'correct_answer': null,
          'numerical_answer': -2.5,
          'question_type': 'numerical',
          'subject': 'Mathematics',
          'marks_correct': 4,
        },
        {'attempted': true, 'is_correct': true, 'marks': 4, 'max_marks': 4},
      );

      expect(question.selected, '-2.5');
      expect(question.correctAnswer, -2.5);
      expect(question.status, ResponseStatus.correct);
    },
  );
}
