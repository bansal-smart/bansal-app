import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';
import '../../skeleton_loading/courses_skeleton.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';
import 'data/courses_providers.dart';

// ── Design tokens — navy, matching the rest of the app ─────────────────────
abstract class _C {
  static const primary = Color(0xFF193F8F);
  static const primaryLt = Color(0xFFEAF0FC);
  static const indigo = Color(0xFF6366F1);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF5F6FA);
  static const border = Color(0xFFE5E7EB);
  static const textPri = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
}

/// Per-enrollment progress, recomputed from video-level tracking rather than
/// trusting the possibly-stale `enrollments.progress_percent` column.
class _EnrollmentProgress {
  final Enrollment enrollment;
  final int percent; // 0-100

  const _EnrollmentProgress(this.enrollment, this.percent);
}

/// Loads all enrollments, then recomputes accurate progress per course from
/// `subtopic_videos` vs `subtopic_video_progress`, falling back to the
/// enrollment's stored `progress_percent` when a course has no videos yet.
final myLearningProvider =
    FutureProvider.autoDispose<List<_EnrollmentProgress>>((ref) async {
      final enrollments = await ref.watch(enrollmentsProvider.future);
      if (enrollments.isEmpty) return [];

      final results = <_EnrollmentProgress>[];
      for (final e in enrollments) {
        final completed = await ref.watch(
          videoProgressProvider(e.courseId).future,
        );
        // videoProgressProvider only returns completed IDs for this course, but
        // we still need the total video count to compute a percentage.
        final totalVideos = await _countCourseVideos(e.courseId);
        final pct = totalVideos > 0
            ? ((completed.length / totalVideos) * 100).round().clamp(0, 100)
            : e.progressPercent;
        results.add(_EnrollmentProgress(e, pct));
      }
      return results;
    });

Future<int> _countCourseVideos(String courseId) async {
  final data = await SupabaseService.client
      .from('subtopic_videos')
      .select('id')
      .eq('course_id', courseId);
  return (data as List).length;
}

// ── Screen ─────────────────────────────────────────────────────────────────
class CoursesListScreen extends ConsumerWidget {
  const CoursesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myLearningProvider);

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: async.when(
          loading: () => const CoursesSkeleton(),
          error: (e, _) => Center(
            child: Text(
              AppException.from(e).userMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.textSub),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _EmptyState(
                onBrowse: () => launchUrl(
                  Uri.parse('https://bansal.ac.in/courses'),
                  mode: LaunchMode.externalApplication,
                ),
              );
            }

            final inProgress = items
                .where((it) => it.percent > 0 && it.percent < 100)
                .length;
            final completed = items.where((it) => it.percent >= 100).length;
            final continueItems = items.where((it) => it.percent < 100).toList()
              ..sort((a, b) {
                final aT =
                    a.enrollment.lastAccessedAt ?? a.enrollment.createdAt;
                final bT =
                    b.enrollment.lastAccessedAt ?? b.enrollment.createdAt;
                return bT.compareTo(aT);
              });
            final continueSlice = continueItems.take(3).toList();

            return RefreshIndicator(
              color: _C.primary,
              onRefresh: () async {
                ref.invalidate(enrollmentsProvider);
                ref.invalidate(myLearningProvider);
                await ref.read(myLearningProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  Text(
                    'My Learning',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: _C.textPri,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${items.length} enrolled · $inProgress in progress · $completed completed',
                    style: const TextStyle(fontSize: 13, color: _C.textSub),
                  ),
                  const SizedBox(height: 16),
                  _StatsStrip(items: items),
                  const SizedBox(height: 20),
                  if (continueSlice.isNotEmpty) ...[
                    const _SectionTitle('Continue Learning'),
                    const SizedBox(height: 10),
                    _CourseCardGrid(
                      items: continueSlice,
                      showBadgePercent: false,
                    ),
                    const SizedBox(height: 20),
                  ],
                  const _SectionTitle('All My Courses'),
                  const SizedBox(height: 10),
                  _CourseCardGrid(items: items, showBadgePercent: true),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Section title ────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: _C.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _C.textPri,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );
}

// ── Stats strip — icon-left, value/label-right rows in a 2x2 grid ─────────
class _StatsStrip extends StatelessWidget {
  final List<_EnrollmentProgress> items;
  const _StatsStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    final enrolled = items.length;
    final inProgress = items
        .where((it) => it.percent > 0 && it.percent < 100)
        .length;
    final completed = items.where((it) => it.percent >= 100).length;
    final avgProgress = items.isEmpty
        ? 0
        : (items.fold<int>(0, (s, it) => s + it.percent) / items.length)
              .round();

    final stats = [
      (
        _C.primary,
        _C.primaryLt,
        Icons.menu_book_rounded,
        '$enrolled',
        'Enrolled',
      ),
      (
        _C.warning,
        const Color(0xFFFFF1E6),
        Icons.play_arrow_rounded,
        '$inProgress',
        'In Progress',
      ),
      (
        _C.warning,
        const Color(0xFFFFF1E6),
        Icons.emoji_events_rounded,
        '$completed',
        'Completed',
      ),
      (
        _C.indigo,
        const Color(0xFFEEF2FF),
        Icons.auto_awesome_rounded,
        '$avgProgress%',
        'Avg Progress',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.4,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final (color, bg, icon, value, label) = stats[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _C.textPri,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: _C.textSub),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Subject → gradient colors, matching the web app's subjectGradient map ──
const Map<String, List<Color>> _subjectGradient = {
  'Physics': [_C.primary, Color(0xFF102A63)],
  'Chemistry': [Color(0xFFFF7A00), Color(0xFFCC5F00)],
  'Maths': [Color(0xFFFF7A00), _C.primary],
  'Mathematics': [Color(0xFFFF7A00), _C.primary],
  'Biology': [Color(0xFFFF7A00), Color(0xFFCC5F00)],
};

List<Color> _gradientFor(String? subject) =>
    _subjectGradient[subject] ?? const [_C.primary, Color(0xFFFF7A00)];

// ── Course card grid — full-bleed thumbnail cards, matching web ───────────
class _CourseCardGrid extends StatelessWidget {
  final List<_EnrollmentProgress> items;
  final bool showBadgePercent;
  const _CourseCardGrid({required this.items, required this.showBadgePercent});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) =>
          _CourseCard(item: items[i], showBadgePercent: showBadgePercent),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final _EnrollmentProgress item;
  final bool showBadgePercent;
  const _CourseCard({required this.item, required this.showBadgePercent});

  @override
  Widget build(BuildContext context) {
    final e = item.enrollment;
    final thumb = e.courseThumbnailUrl ?? '';
    final isDone = item.percent >= 100;
    final gradient = _gradientFor(e.courseSubject);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/my-courses/${e.courseId}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  if (thumb.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    )
                  else
                    Center(
                      child: Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white.withValues(alpha: 0.40),
                        size: 34,
                      ),
                    ),
                  if (showBadgePercent)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDone
                              ? _C.warning
                              : Colors.black.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isDone) ...[
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                            ],
                            Text(
                              '${item.percent}%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!showBadgePercent)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (!showBadgePercent)
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (e.courseSubject != null)
                                  Text(
                                    e.courseSubject!.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                Text(
                                  e.courseTitle ?? 'Course',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: gradient.first,
                              size: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBadgePercent) ...[
                    if (e.courseSubject != null)
                      Text(
                        e.courseSubject!.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: _C.textSub,
                          letterSpacing: 0.3,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      e.courseTitle ?? 'Course',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _C.textPri,
                      ),
                    ),
                    if (e.courseEducatorName != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        e.courseEducatorName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _C.textSub),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ] else ...[
                    Row(
                      children: [
                        Text(
                          '${item.percent}% complete',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: item.percent / 100,
                      minHeight: 5,
                      backgroundColor: _C.border,
                      color: isDone ? _C.success : _C.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyState({required this.onBrowse});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _C.primaryLt,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_outlined,
              color: _C.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No courses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _C.textPri,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enroll in a course from the store to start learning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _C.textSub, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onBrowse,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: const Text(
              'Browse Courses',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    ),
  );
}
