import 'package:bansal/features/tests/data/models/app_test.dart';
import 'package:bansal/features/tests/data/models/test_attempt.dart';
import 'package:bansal/features/tests/data/tests_providers.dart';
import 'package:flutter_test/flutter_test.dart';

AppTest cbtTest({required DateTime endsAt}) => AppTest(
  id: 'test-1',
  title: 'CBT Test',
  testType: 'mock',
  examPattern: 'JEE',
  subjects: const ['Physics'],
  durationMinutes: 180,
  totalMarks: 300,
  totalQuestions: 75,
  visibility: 'batch',
  endsAt: endsAt,
  testMode: 'cbt',
);

void main() {
  final now = DateTime.utc(2026, 9, 11, 10);

  test('unstarted CBT remains available before its end time', () {
    final item = TestWithStatus(
      test: cbtTest(endsAt: now.add(const Duration(hours: 2))),
    );

    expect(item.isCbtAbsentAt(now), isFalse);
  });

  test('CBT is absent only after it ends without an attempt', () {
    final item = TestWithStatus(
      test: cbtTest(endsAt: now.subtract(const Duration(minutes: 1))),
    );

    expect(item.isCbtAbsentAt(now), isTrue);
  });

  test('an existing attempt is never classified as absent', () {
    final item = TestWithStatus(
      test: cbtTest(endsAt: now.subtract(const Duration(hours: 1))),
      attempt: const TestAttempt(
        id: 'attempt-1',
        testId: 'test-1',
        status: 'submitted',
      ),
    );

    expect(item.isCbtAbsentAt(now), isFalse);
    expect(item.isSubmitted, isTrue);
  });
}
