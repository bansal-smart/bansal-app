import 'package:bansal/features/profile/data/dashboard_stats_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateActivityStreak', () {
    test('counts today and consecutive preceding days once each', () {
      final now = DateTime(2026, 8, 26, 18);
      final result = calculateActivityStreak([
        DateTime(2026, 8, 26, 9),
        DateTime(2026, 8, 26, 17),
        DateTime(2026, 8, 25, 12),
        DateTime(2026, 8, 24, 23),
        DateTime(2026, 8, 22),
      ], now);

      expect(result, 3);
    });

    test('keeps a streak through yesterday when today has no activity', () {
      final result = calculateActivityStreak([
        DateTime(2026, 8, 25),
        DateTime(2026, 8, 24),
      ], DateTime(2026, 8, 26));

      expect(result, 2);
    });

    test('returns zero after a full missed day', () {
      final result = calculateActivityStreak([
        DateTime(2026, 8, 24),
        DateTime(2026, 8, 23),
      ], DateTime(2026, 8, 26));

      expect(result, 0);
    });
  });

  group('calculateOverallAccuracy', () {
    test('uses attempted questions rather than all questions', () {
      final result = calculateOverallAccuracy([
        {
          'correct_answers': 6,
          'total_questions': 20,
          'metadata': {'attempted': 8},
        },
        {
          'correct_answers': 3,
          'total_questions': 10,
          'metadata': {'attempted': 4},
        },
      ]);

      expect(result, 75);
    });

    test('uses total questions for legacy attempts without metadata', () {
      final result = calculateOverallAccuracy([
        {'correct_answers': 7, 'total_questions': 10, 'metadata': null},
      ]);

      expect(result, 70);
    });

    test('returns null when no questions were attempted', () {
      expect(calculateOverallAccuracy(const []), isNull);
    });
  });
}
