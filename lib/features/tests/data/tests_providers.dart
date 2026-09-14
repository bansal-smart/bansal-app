import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../enrollments/data/enrollments_providers.dart';
import 'models/app_test.dart';
import 'models/test_attempt.dart';
import 'repositories/tests_repository.dart';

final testsRepositoryProvider = Provider<TestsRepository>((ref) {
  return TestsRepository();
});

final testsProvider = FutureProvider.autoDispose<List<AppTest>>((ref) async {
  final repo = ref.watch(testsRepositoryProvider);
  return repo.fetchPublished();
});

// Tests linked to a specific course via course_id column.
final courseTestsProvider = FutureProvider.autoDispose
    .family<List<AppTest>, String>((ref, courseId) async {
      final client = SupabaseService.client;
      final data = await client
          .from('tests')
          .select(testSelectColumns)
          .eq('course_id', courseId)
          .eq('is_published', true)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => AppTest.fromJson(r as Map<String, dynamic>))
          .toList();
    });

final myAttemptsProvider = FutureProvider.autoDispose<List<TestAttempt>>((
  ref,
) async {
  final repo = ref.watch(testsRepositoryProvider);
  return repo.fetchMyAttempts();
});

final myAssignedTestIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final repo = ref.watch(testsRepositoryProvider);
  return repo.fetchMyAssignedTestIds();
});

final myApprovedReattemptTestIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final repo = ref.watch(testsRepositoryProvider);
      return repo.fetchMyApprovedReattemptTestIds();
    });

final myBatchIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final repo = ref.watch(testsRepositoryProvider);
  return repo.fetchMyBatchId();
});

/// Same priority as the web test list: an attempt the student can resume takes
/// precedence over an older completed attempt for the same test.
Map<String, TestAttempt> _attemptByTestId(List<TestAttempt> attempts) {
  final map = <String, TestAttempt>{};
  for (final a in attempts) {
    final existing = map[a.testId];
    if (existing == null || (!existing.isInProgress && a.isInProgress)) {
      map[a.testId] = a;
    }
  }
  return map;
}

class TestWithStatus {
  final AppTest test;
  final TestAttempt? attempt;
  final bool reattemptApproved;

  const TestWithStatus({
    required this.test,
    this.attempt,
    this.reattemptApproved = false,
  });

  /// A missing attempt does not mean the student is absent while the exam is
  /// still available. Absence is only meaningful after its configured window
  /// has ended.
  bool isCbtAbsentAt(DateTime now) {
    final endsAt = test.endsAt;
    return test.isCbt &&
        attempt == null &&
        endsAt != null &&
        now.isAfter(endsAt);
  }

  bool get isCbtAbsent => isCbtAbsentAt(DateTime.now());
  bool get isSubmitted => attempt?.isSubmitted ?? false;
  bool get isInProgress => attempt?.isInProgress ?? false;
  bool get canStartApprovedReattempt => isSubmitted && reattemptApproved;
}

class TestGroup {
  final String key;
  final String label;
  final List<TestWithStatus> tests;

  const TestGroup({
    required this.key,
    required this.label,
    required this.tests,
  });
}

const generalGroupKey = '__general__';

/// Tests the student can access, each paired with their attempt status,
/// grouped by enrolled course (plus a trailing "General Practice" group),
/// mirroring the web app's `/my-tests` visibility + grouping logic exactly.
final accessibleTestGroupsProvider =
    FutureProvider.autoDispose<List<TestGroup>>((ref) async {
      final enrollments = await ref.watch(enrollmentsProvider.future);
      final allTests = await ref.watch(testsProvider.future);
      final attempts = await ref.watch(myAttemptsProvider.future);
      final assignedIds = await ref.watch(myAssignedTestIdsProvider.future);
      final approvedReattemptIds = await ref.watch(
        myApprovedReattemptTestIdsProvider.future,
      );
      final batchId = await ref.watch(myBatchIdProvider.future);

      final attemptByTestId = _attemptByTestId(attempts);
      final enrolledCourseIds = enrollments.map((e) => e.courseId).toSet();

      bool isVisible(AppTest t) {
        if (attemptByTestId.containsKey(t.id)) return true;
        if (assignedIds.contains(t.id)) return true;
        final inBatch =
            batchId != null && t.cbtAllowedBatchIds.contains(batchId);
        if (t.isCbt) {
          // Keep the exact web catalogue rule. A batch CBT without an attempt
          // is shown with the released catalogue; directly assigned CBTs are
          // already handled above.
          return t.resultsReleasedAt != null && inBatch;
        }
        final isOpen = t.cbtAllowedBatchIds.isEmpty;
        final inCourse =
            t.courseId != null && enrolledCourseIds.contains(t.courseId);
        return isOpen || inBatch || inCourse;
      }

      final visibleTests = allTests.where(isVisible).toList();

      final groups = <TestGroup>[];
      for (final e in enrollments) {
        final tests = visibleTests
            .where((t) => t.courseId == e.courseId)
            .map(
              (t) => TestWithStatus(
                test: t,
                attempt: attemptByTestId[t.id],
                reattemptApproved: approvedReattemptIds.contains(t.id),
              ),
            )
            .toList();
        if (tests.isEmpty) continue;
        groups.add(
          TestGroup(
            key: e.courseId,
            label: e.courseTitle ?? 'Course',
            tests: tests,
          ),
        );
      }

      final generalTests = visibleTests
          .where(
            (t) =>
                t.courseId == null || !enrolledCourseIds.contains(t.courseId),
          )
          .map(
            (t) => TestWithStatus(
              test: t,
              attempt: attemptByTestId[t.id],
              reattemptApproved: approvedReattemptIds.contains(t.id),
            ),
          )
          .toList();
      if (generalTests.isNotEmpty) {
        groups.add(
          TestGroup(
            key: generalGroupKey,
            label: 'General Practice',
            tests: generalTests,
          ),
        );
      }

      return groups;
    });
