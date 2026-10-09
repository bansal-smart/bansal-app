import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/motion.dart';
import '../../skeleton_loading/courses_skeleton.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';
import '../profile/data/dashboard_stats_providers.dart';
import 'data/courses_providers.dart';
import 'data/models/course_subject.dart';

// ── Design tokens — navy, matching the rest of the app ─────────────────────
abstract class _C {
  static const primary = Color(0xFF193F8F);
  static const primaryLt = Color(0xFFEAF0FC);
  static const indigo = Color(0xFF6366F1);
  static const textSub = Color(0xFF6B7280);
  static const peachTile = Color(0xFFFDEEDC);
  static const lavenderTile = Color(0xFFEEEFFC);
  static const cream = Color(0xFFF6EAD8);

  static const cardShadow = [
    BoxShadow(color: Color(0x14102A5C), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

// ── Motion — paced from the Figma prototype video ───────────────────────────
// Overview card drops in first; inside it the course pill pops, the stat
// tiles fill one by one and the weekly bars rise. The Continue Learning card
// scales in just after, then the subject rows cascade in from the right.
// (Shared helpers — withMotion, cascade, Pressable — live in core/widgets.)
abstract class _Motion {
  static const statsStart = Duration(milliseconds: 250);
  static const statsStep = Duration(milliseconds: 120);
  static const barsStart = Duration(milliseconds: 650);
  static const barStep = Duration(milliseconds: 50);
  static const listStart = Duration(milliseconds: 300);
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
    final weeklyMinutes =
        ref.watch(weeklyStudyMinutesProvider).valueOrNull ??
        List<int>.filled(7, 0);

    return Scaffold(
      backgroundColor: Colors.transparent,
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

            // Most recently opened course drives the hero, continue card and
            // subject list.
            final byRecent = [...items]
              ..sort((a, b) {
                final aT =
                    a.enrollment.lastAccessedAt ?? a.enrollment.createdAt;
                final bT =
                    b.enrollment.lastAccessedAt ?? b.enrollment.createdAt;
                return bT.compareTo(aT);
              });
            final featured = byRecent.firstWhere(
              (it) => it.percent < 100,
              orElse: () => byRecent.first,
            );
            final others = byRecent.where((it) => it != featured).toList();

            return RefreshIndicator(
              color: _C.primary,
              onRefresh: () async {
                ref.invalidate(enrollmentsProvider);
                ref.invalidate(myLearningProvider);
                ref.invalidate(weeklyStudyMinutesProvider);
                await ref.read(myLearningProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  const Text(
                    'My Learning',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // 1. Summary card drops in from slightly above.
                  _OverviewCard(
                    items: items,
                    featured: featured,
                    weeklyMinutes: weeklyMinutes,
                  ).withMotion(
                    context,
                    (a) => a
                        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                        .slideY(
                          begin: -0.15,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Continue Learning'),
                  const SizedBox(height: 14),
                  // 2. Continue Learning pops in just after.
                  _ContinueCard(item: featured).withMotion(
                    context,
                    (a) => a
                        .fadeIn(
                          delay: 200.ms,
                          duration: 600.ms,
                          curve: Curves.easeOut,
                        )
                        .scale(
                          begin: const Offset(0.95, 0.95),
                          end: const Offset(1, 1),
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                  const SizedBox(height: 28),
                  const _SectionTitle('Subjects'),
                  const SizedBox(height: 14),
                  // 3. Subject rows cascade in (see _SubjectList).
                  _SubjectList(courseId: featured.enrollment.courseId),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const _SectionTitle('My Courses'),
                    const SizedBox(height: 14),
                    ...[
                      for (var i = 0; i < others.length; i++)
                        Padding(
                          padding: EdgeInsets.only(top: i > 0 ? 12 : 0),
                          child: _CourseRow(item: others[i], tint: _rowTint(i)),
                        ),
                    ].cascade(context, delay: _Motion.listStart),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Alternating blue / peach list tints from the design.
Color _rowTint(int i) => i.isEven ? AppColors.tileBlue : _C.peachTile;

// ── Section title ────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: 0.3,
    ),
  );
}

// ── Overview: featured course, weekly bars and 2x2 stats ─────────────────
class _OverviewCard extends StatelessWidget {
  final List<_EnrollmentProgress> items;
  final _EnrollmentProgress featured;
  final List<int> weeklyMinutes;

  const _OverviewCard({
    required this.items,
    required this.featured,
    required this.weeklyMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final e = featured.enrollment;
    final inProgress = items
        .where((it) => it.percent > 0 && it.percent < 100)
        .length;
    final avgProgress =
        (items.fold<int>(0, (s, it) => s + it.percent) / items.length).round();
    final meta = [
      e.courseSubject,
      e.courseEducatorName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33102A5C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 9,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Wraps at word boundaries; long course names stay
                    // readable instead of being cut to "ONLINE - B…".
                    child: Text(
                      e.courseTitle ?? 'My Course',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ).withMotion(
                    // The pill "pops": starts a touch larger and settles.
                    context,
                    (a) => a.scale(
                      begin: const Offset(1.12, 1.12),
                      end: const Offset(1, 1),
                      duration: 450.ms,
                      curve: Curves.easeOutBack,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Spacer(),
                  _WeekBars(minutes: weeklyMinutes),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 11,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: LucideIcons.trophy,
                          iconColor: AppColors.orange,
                          tint: _C.peachTile,
                          value: '${featured.percent}%',
                          label: 'Completed',
                          order: 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: LucideIcons.sparkles,
                          iconColor: _C.indigo,
                          tint: _C.lavenderTile,
                          value: '$avgProgress%',
                          label: 'Avg Progress',
                          order: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: LucideIcons.bookOpenText,
                          iconColor: _C.primary,
                          tint: AppColors.tileBlue,
                          value: '${items.length}',
                          label: 'Enrolled',
                          order: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatTile(
                          icon: LucideIcons.play,
                          iconColor: AppColors.orange,
                          tint: _C.peachTile,
                          value: '$inProgress',
                          label: 'In Progress',
                          order: 3,
                        ),
                      ),
                    ],
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

class _WeekBars extends StatelessWidget {
  /// Minutes studied per day, Monday first.
  final List<int> minutes;
  const _WeekBars({required this.minutes});

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _maxBar = 56;
  static const double _minBar = 8;

  @override
  Widget build(BuildContext context) {
    final peak = minutes.fold<int>(0, (a, b) => a > b ? a : b);
    final today = DateTime.now().weekday - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        final ratio = peak == 0 ? 0.0 : minutes[i] / peak;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bars rise from the baseline one after another.
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: 9,
              height: _minBar + (_maxBar - _minBar) * ratio,
              decoration: BoxDecoration(
                color: i == today ? AppColors.orange : _C.cream,
                borderRadius: BorderRadius.circular(999),
              ),
            ).withMotion(
              context,
              (a) => a
                  .fadeIn(
                    delay: _Motion.barsStart + _Motion.barStep * i,
                    duration: 250.ms,
                  )
                  .scaleY(
                    begin: 0,
                    end: 1,
                    alignment: Alignment.bottomCenter,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              _days[i],
              style: TextStyle(
                fontSize: 7,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color tint;
  final String value;
  final String label;

  /// Position in the fill-in sequence (0 = first).
  final int order;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.tint,
    required this.value,
    required this.label,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      // The tile is there from the start; its contents fill in one tile
      // after another, as in the reference video.
      child:
          Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: iconColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Scales down in the narrow 2x2 grid rather than cutting off.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 10, color: _C.primary),
                ),
              ),
            ],
          ).withMotion(
            context,
            (a) => a
                .fadeIn(
                  delay: _Motion.statsStart + _Motion.statsStep * order,
                  duration: 350.ms,
                  curve: Curves.easeOut,
                )
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutCubic,
                ),
          ),
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

/// Course thumbnail with the subject gradient behind it as a fallback.
class _Thumbnail extends StatelessWidget {
  final Enrollment enrollment;
  const _Thumbnail({required this.enrollment});

  @override
  Widget build(BuildContext context) {
    final thumb = enrollment.courseThumbnailUrl ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradientFor(enrollment.courseSubject),
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
          Icon(
            LucideIcons.bookOpen,
            color: Colors.white.withValues(alpha: 0.5),
            size: 30,
          ),
      ],
    );
  }
}

void _openCourse(BuildContext context, Enrollment e) {
  HapticFeedback.selectionClick();
  context.push('/my-courses/${e.courseId}');
}

// ── Continue Learning card ───────────────────────────────────────────────
class _ContinueCard extends StatelessWidget {
  final _EnrollmentProgress item;
  const _ContinueCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final e = item.enrollment;
    return Pressable(
      child: GestureDetector(
        onTap: () => _openCourse(context, e),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: _C.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 104,
                height: 74,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _C.cardShadow,
                ),
                child: _Thumbnail(enrollment: e),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.courseSubject != null) ...[
                      Text(
                        e.courseSubject!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.courseTitle ?? 'Course',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 26,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${item.percent}% complete',
                      style: const TextStyle(fontSize: 10.5, color: _C.textSub),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: item.percent / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subjects of the featured course ──────────────────────────────────────
class _SubjectList extends ConsumerWidget {
  final String courseId;
  const _SubjectList({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(courseSubjectsProvider(courseId));
    return subjects.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text(
        AppException.from(e).userMessage,
        style: const TextStyle(fontSize: 12, color: _C.textSub),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const Text(
            'Subjects will appear here once added to this course.',
            style: TextStyle(fontSize: 12, color: _C.textSub),
          );
        }
        // Rows cascade in one after another (100ms apart), sliding from
        // the right, as in the reference video.
        return Column(
          children: [
            for (var i = 0; i < list.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i > 0 ? 14 : 0),
                child: _SubjectRow(subject: list[i], tint: _rowTint(i)),
              ),
          ].cascade(context, delay: _Motion.listStart),
        );
      },
    );
  }
}

class _SubjectRow extends ConsumerWidget {
  final CourseSubject subject;
  final Color tint;
  const _SubjectRow({required this.subject, required this.tint});

  static const _short = {
    'physics': 'PHY',
    'chemistry': 'CHEM',
    'mathematics': 'MATH',
    'maths': 'MATH',
    'biology': 'BIO',
    'botany': 'BOT',
    'zoology': 'ZOO',
    'english': 'ENG',
  };

  String get _abbr {
    final name = subject.name.trim();
    final known = _short[name.toLowerCase()];
    if (known != null) return known;
    if (name.isEmpty) return '—';
    return name.substring(0, name.length < 3 ? name.length : 3).toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(courseTopicsProvider(subject.id)).valueOrNull;
    return _ListRow(
      tint: tint,
      leading: Text(
        _abbr,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _C.textSub,
        ),
      ),
      title: subject.name,
      subtitle: topics == null
          ? ''
          : '${topics.length} ${topics.length == 1 ? 'topic' : 'topics'}',
      onTap: () {
        HapticFeedback.selectionClick();
        context.push(
          '/my-courses/${subject.courseId}/subject/${subject.id}',
          extra: subject.name,
        );
      },
    );
  }
}

/// Another enrolled course, styled like a subject row.
class _CourseRow extends StatelessWidget {
  final _EnrollmentProgress item;
  final Color tint;
  const _CourseRow({required this.item, required this.tint});

  @override
  Widget build(BuildContext context) {
    final e = item.enrollment;
    return _ListRow(
      tint: tint,
      leading: _Thumbnail(enrollment: e),
      title: e.courseTitle ?? 'Course',
      subtitle: '${item.percent}% complete',
      onTap: () => _openCourse(context, e),
    );
  }
}

class _ListRow extends StatelessWidget {
  final Color tint;
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ListRow({
    required this.tint,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Subject and course rows shrink slightly under the finger.
    return Pressable(
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: _C.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 46,
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _C.lavenderTile,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white),
                  ),
                  child: leading,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: _C.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight200,
                  size: 26,
                  color: _C.textSub,
                ),
              ],
            ),
          ),
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
    child:
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: _C.cardShadow,
          ),
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
                  LucideIcons.graduationCap,
                  color: _C.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No courses yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enroll in a course from the store to start learning.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _C.textSub,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Pressable(
                child: ElevatedButton.icon(
                  onPressed: onBrowse,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(LucideIcons.store, size: 18),
                  label: const Text(
                    'Browse Courses',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ).withMotion(
          context,
          (a) => a
              .fadeIn(duration: 500.ms, curve: Curves.easeOut)
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                curve: Curves.easeOutCubic,
              ),
        ),
  );
}
