import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class ProfileStats {
  final int hoursStudied;
  final int testsAttempted;
  final int enrolledCourses;
  final int dayStreak;

  const ProfileStats({
    required this.hoursStudied,
    required this.testsAttempted,
    required this.enrolledCourses,
    required this.dayStreak,
  });
}

class ActivityItem {
  final String title;
  final String timeAgo;
  final String type; // 'lesson' | 'test' | 'live'
  final DateTime createdAt;
  final String? targetId; // lessonId, testId, or liveClassId
  final String? secondaryId; // courseId for lessons

  const ActivityItem({
    required this.title,
    required this.timeAgo,
    required this.type,
    required this.createdAt,
    this.targetId,
    this.secondaryId,
  });
}

class ProfileStatsRepository {
  final SupabaseClient _client;

  ProfileStatsRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  Future<ProfileStats> fetchStats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null)
      return const ProfileStats(
        hoursStudied: 0,
        testsAttempted: 0,
        enrolledCourses: 0,
        dayStreak: 0,
      );

    final results = await Future.wait([
      _fetchMinutesStudied(userId),
      _fetchTestsAttempted(userId),
      _fetchEnrolledCount(userId),
      _fetchDayStreak(userId),
    ]);

    return ProfileStats(
      hoursStudied: (results[0] / 60).round(),
      testsAttempted: results[1],
      enrolledCourses: results[2],
      dayStreak: results[3],
    );
  }

  Future<List<ActivityItem>> fetchRecentActivity() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final results = await Future.wait([
      _fetchRecentLessons(userId),
      _fetchRecentTests(userId),
      _fetchRecentLiveClasses(userId),
    ]);

    final all = [...results[0], ...results[1], ...results[2]];
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(5).toList();
  }

  Future<int> _fetchMinutesStudied(String userId) async {
    final data = await _client
        .from('study_sessions')
        .select('minutes_studied')
        .eq('user_id', userId);
    final list = data as List<dynamic>;
    return list.fold<int>(
      0,
      (sum, r) => sum + ((r['minutes_studied'] as int?) ?? 0),
    );
  }

  Future<int> _fetchTestsAttempted(String userId) async {
    final data = await _client
        .from('test_attempts')
        .select('id')
        .eq('user_id', userId);
    return (data as List<dynamic>).length;
  }

  Future<int> _fetchEnrolledCount(String userId) async {
    final data = await _client
        .from('enrollments')
        .select('id')
        .eq('user_id', userId)
        .eq('is_active', true);
    return (data as List<dynamic>).length;
  }

  Future<int> _fetchDayStreak(String userId) async {
    final data = await _client
        .from('study_sessions')
        .select('session_date')
        .eq('user_id', userId)
        .order('session_date', ascending: false);
    final dates = (data as List<dynamic>)
        .map((r) => DateTime.tryParse(r['session_date'].toString()))
        .whereType<DateTime>()
        .toList();

    if (dates.isEmpty) return 0;

    int streak = 0;
    var expected = DateTime.now().toUtc();
    for (final d in dates) {
      final day = DateTime.utc(d.year, d.month, d.day);
      final exp = DateTime.utc(expected.year, expected.month, expected.day);
      final diff = exp.difference(day).inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        expected = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<ActivityItem>> _fetchRecentLessons(String userId) async {
    final data = await _client
        .from('lesson_progress')
        .select('lesson_id, course_id, lesson_title, last_watched_at')
        .eq('user_id', userId)
        .order('last_watched_at', ascending: false)
        .limit(3);
    return (data as List<dynamic>).map((r) {
      final at =
          DateTime.tryParse(r['last_watched_at']?.toString() ?? '') ??
          DateTime.now();
      return ActivityItem(
        title: 'Watched "${r['lesson_title'] ?? 'a lesson'}"',
        timeAgo: _timeAgo(at),
        type: 'lesson',
        createdAt: at,
        targetId: r['course_id']?.toString(),
        secondaryId: r['lesson_id']?.toString(),
      );
    }).toList();
  }

  Future<List<ActivityItem>> _fetchRecentTests(String userId) async {
    final data = await _client
        .from('test_attempts')
        .select('id, test_id, test_name, attempted_at, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(2);
    return (data as List<dynamic>).map((r) {
      final at =
          DateTime.tryParse(
            r['attempted_at']?.toString() ?? r['created_at']?.toString() ?? '',
          ) ??
          DateTime.now();
      return ActivityItem(
        title: 'Attempted "${r['test_name'] ?? 'a test'}"',
        timeAgo: _timeAgo(at),
        type: 'test',
        createdAt: at,
        targetId: r['test_id']?.toString(),
        secondaryId: r['id']?.toString(),
      );
    }).toList();
  }

  Future<List<ActivityItem>> _fetchRecentLiveClasses(String userId) async {
    final data = await _client
        .from('live_class_attendance')
        .select('joined_at, live_class_id, live_classes(id, title)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false)
        .limit(2);
    return (data as List<dynamic>).map((r) {
      final at =
          DateTime.tryParse(r['joined_at']?.toString() ?? '') ?? DateTime.now();
      final liveClass = r['live_classes'] as Map<String, dynamic>?;
      final title = liveClass?['title'] ?? 'a live class';
      final liveId = (r['live_class_id'] ?? liveClass?['id'])?.toString();
      return ActivityItem(
        title: 'Joined live class: $title',
        timeAgo: _timeAgo(at),
        type: 'live',
        createdAt: at,
        targetId: liveId,
      );
    }).toList();
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
