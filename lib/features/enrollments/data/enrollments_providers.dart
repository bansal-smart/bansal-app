import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/enrollment.dart';
import 'repositories/enrollments_repository.dart';

final enrollmentsRepositoryProvider = Provider<EnrollmentsRepository>((ref) {
  return EnrollmentsRepository();
});

final enrollmentsProvider = FutureProvider.autoDispose<List<Enrollment>>((
  ref,
) async {
  final repo = ref.watch(enrollmentsRepositoryProvider);
  return repo.fetchMyEnrollments();
});
