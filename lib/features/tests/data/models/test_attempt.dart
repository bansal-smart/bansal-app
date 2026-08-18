class TestAttempt {
  final String id;
  final String testId;
  final String status;

  const TestAttempt({
    required this.id,
    required this.testId,
    required this.status,
  });

  bool get isSubmitted => status == 'submitted' || status == 'auto_submitted';
  bool get isInProgress => status == 'in_progress';

  factory TestAttempt.fromJson(Map<String, dynamic> json) => TestAttempt(
    id: json['id'] as String,
    testId: json['test_id'] as String,
    status: json['status'] as String? ?? 'submitted',
  );
}
