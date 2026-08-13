import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/providers.dart';
import '../../skeleton_loading/home_skeleton.dart';
import '../../core/widgets/async_value_widget.dart';
import '../courses/data/courses_providers.dart';
import '../courses/data/models/course.dart';
import '../live/data/live_providers.dart';
import '../live/data/models/live_class.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';

abstract class DS {
  static const primary = Color(0xFFF97315);
  static const primaryLight = Color(0xFFFFF0E6);
  static const primaryDark = Color(0xFFE05A00);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(accessibleLiveClassesProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final enrollmentsAsync = ref.watch(enrollmentsProvider);
    final profileInfo = ref.watch(profileSetupInfoProvider);
    final exam = profileInfo.exam;
    final userClass = profileInfo.userClass;
    final showSkeleton =
        liveAsync.isLoading &&
        coursesAsync.isLoading &&
        enrollmentsAsync.isLoading;

    return ColoredBox(
      color: DS.background,
      child: showSkeleton
          ? const HomeSkeleton()
          : RefreshIndicator(
              color: DS.primary,
              onRefresh: () async {
                ref.invalidate(accessibleLiveClassesProvider);
                ref.invalidate(coursesProvider);
                ref.invalidate(enrollmentsProvider);
                await Future.wait([
                  ref.read(accessibleLiveClassesProvider.future),
                  ref.read(coursesProvider.future),
                  ref.read(enrollmentsProvider.future),
                ]);
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Recent Activity ──
                  const SizedBox(height: DS.s20),
                  _SectionHeader(
                    title: 'Recent Activity',
                    icon: Icons.history_rounded,
                    color: DS.warning,
                  ),
                  const SizedBox(height: DS.s12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s16,
                        vertical: DS.s20,
                      ),
                      decoration: BoxDecoration(
                        color: DS.surface,
                        borderRadius: BorderRadius.circular(DS.radiusLg),
                        border: Border.all(color: DS.border, width: 1.2),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.history_rounded,
                              color: DS.textHint, size: 20),
                          SizedBox(width: DS.s10),
                          Text(
                            'No recent activity yet.',
                            style: TextStyle(
                              fontSize: 13,
                              color: DS.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Course Activity ──
                  _SectionHeader(
                    title: 'Course Activity',
                    icon: Icons.menu_book_rounded,
                    color: DS.primary,
                    actionLabel: 'See all',
                    onAction: () => context.push('/my-courses'),
                  ),
                  const SizedBox(height: DS.s12),
                  AsyncValueWidget(
                    value: enrollmentsAsync,
                    loadingWidget: const SizedBox.shrink(),
                    isEmpty: (e) => e.isEmpty,
                    emptyMessage: 'You have not enrolled in any course yet.',
                    emptyIcon: Icons.school_outlined,
                    data: (enrollments) {
                      final sorted = [...enrollments]..sort((a, b) {
                          final aTime = a.lastAccessedAt ?? a.createdAt;
                          final bTime = b.lastAccessedAt ?? b.createdAt;
                          return bTime.compareTo(aTime);
                        });
                      final recent = sorted.take(1).toList();
                      return _EnrollmentCarousel(
                        enrollments: recent,
                        onResume: (e) =>
                            context.push('/my-courses/${e.courseId}'),
                      );
                    },
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Upcoming live classes ──
                  _SectionHeader(
                    title: 'Upcoming Live Classes',
                    icon: Icons.sensors_rounded,
                    color: DS.error,
                    actionLabel: 'See all',
                    onAction: () => context.push('/live'),
                  ),
                  const SizedBox(height: DS.s12),
                  SizedBox(
                    height: 178,
                    child: AsyncValueWidget(
                      value: liveAsync,
                      isEmpty: (classes) =>
                          classes.where((c) => !c.isPast).isEmpty,
                      emptyMessage: 'No upcoming classes',
                      emptyIcon: Icons.sensors_off_rounded,
                      errorPadding: const EdgeInsets.symmetric(horizontal: 16),
                      data: (classes) {
                        final upcoming = classes
                            .where((c) => !c.isPast)
                            .toList();
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DS.s16,
                          ),
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: upcoming.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: DS.s12),
                          itemBuilder: (_, i) {
                            final lc = upcoming[i];
                            return _LiveCard(
                              live: lc,
                              onTap: () => context.push('/live/${lc.id}'),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Recommended courses ──
                  _SectionHeader(
                    title: 'Recommended Courses',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF6366F1),
                    actionLabel: 'See all',
                    onAction: () => context.go('/courses'),
                  ),
                  const SizedBox(height: DS.s12),
                  AsyncValueWidget(
                    value: coursesAsync,
                    isEmpty: (courses) => courses.isEmpty,
                    emptyMessage: 'No courses available yet.',
                    emptyIcon: Icons.menu_book_outlined,
                    data: (courses) {
                      final filtered = exam.isEmpty
                          ? courses
                          : exam == 'Foundation'
                          ? courses.where((c) {
                              if (c.target != 'Foundation') return false;
                              if (userClass.isEmpty) return true;
                              final cls = userClass
                                  .replaceAll('th', '')
                                  .replaceAll('st', '')
                                  .replaceAll('nd', '')
                                  .replaceAll('rd', '');
                              return c.courseClass == cls;
                            }).toList()
                          : courses.where((c) => c.target == exam).toList();
                      final featured = filtered.take(6).toList();
                      return _CoursesCarousel(
                        courses: featured,
                        onTap: (c) => context.push('/course/${c.id}'),
                        onContinue: (c) => context.push('/my-courses/${c.id}'),
                      );
                    },
                  ),

                  const SizedBox(height: DS.s32),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: DS.s10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: DS.s4,
                ),
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DS.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Carousel wrapper ────────────────────────────────────────────────────────
class _EnrollmentCarousel extends StatefulWidget {
  final List<Enrollment> enrollments;
  final void Function(Enrollment) onResume;
  const _EnrollmentCarousel({
    required this.enrollments,
    required this.onResume,
  });

  @override
  State<_EnrollmentCarousel> createState() => _EnrollmentCarouselState();
}

class _EnrollmentCarouselState extends State<_EnrollmentCarousel> {
  final _ctrl = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.enrollments.length;
    final single = count == 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          // Fixed height so cards don't collapse inside the ListView
          height: 168,
          child: single
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                  child: _ContinueCard(
                    enrollment: widget.enrollments.first,
                    onResume: () => widget.onResume(widget.enrollments.first),
                  ),
                )
              : PageView.builder(
                  controller: _ctrl,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final e = widget.enrollments[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? DS.s16 : DS.s6,
                        right: i == count - 1 ? DS.s16 : DS.s6,
                      ),
                      child: _ContinueCard(
                        enrollment: e,
                        onResume: () => widget.onResume(e),
                      ),
                    );
                  },
                ),
        ),
        if (!single) ...[
          const SizedBox(height: DS.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? DS.primary : DS.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

// ── Single course card ───────────────────────────────────────────────────────
class _ContinueCard extends StatelessWidget {
  final Enrollment enrollment;
  final VoidCallback onResume;
  const _ContinueCard({required this.enrollment, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final thumb = enrollment.courseThumbnailUrl ?? '';
    return GestureDetector(
      onTap: onResume,
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.s14, DS.s14, DS.s14, DS.s14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(DS.radiusSm),
                child: thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        width: 80,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (ctx, url) => Container(
                          width: 80,
                          height: 100,
                          color: DS.surfaceVariant,
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 100,
                        color: DS.surfaceVariant,
                        child: const Icon(
                          Icons.menu_book,
                          color: DS.primary,
                          size: 28,
                        ),
                      ),
              ),
              const SizedBox(width: DS.s14),
              // Info + button
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // "Continue Learning" pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s8,
                        vertical: DS.s4,
                      ),
                      decoration: BoxDecoration(
                        color: DS.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 11,
                            color: DS.primary,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Continue Learning',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: DS.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: DS.s8),
                    // Course title
                    Text(
                      enrollment.courseTitle ?? 'Course',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DS.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (enrollment.courseSubject != null) ...[
                      const SizedBox(height: DS.s4),
                      Text(
                        enrollment.courseSubject!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: DS.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: DS.s10),
                    // Resume button
                    SizedBox(
                      height: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8C38), DS.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          boxShadow: [
                            BoxShadow(
                              color: DS.primary.withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: onResume,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.s12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DS.radiusSm),
                            ),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text(
                            'Resume',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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

class _LiveCard extends StatelessWidget {
  final LiveClass live;
  final VoidCallback onTap;
  const _LiveCard({required this.live, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLive = live.isLive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(
            color: isLive ? DS.error.withValues(alpha: 0.25) : DS.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLive ? DS.error : Colors.black).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(DS.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(isLive: isLive),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: DS.border, width: 1),
                  ),
                  child: Text(
                    live.subject,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s10),
            Text(
              live.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
                letterSpacing: -0.2,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DS.s6),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: DS.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: DS.primary,
                  ),
                ),
                const SizedBox(width: DS.s6),
                Expanded(
                  child: Text(
                    live.educatorName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DS.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Divider(color: DS.border, height: DS.s16, thickness: 1),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isLive ? DS.error : DS.textSecondary,
                ),
                const SizedBox(width: DS.s4),
                Text(
                  _fmt(live.startsAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLive ? DS.error : DS.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? DS.error.withValues(alpha: 0.08)
                        : DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isLive ? 'Join Now' : 'Set Reminder',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLive ? DS.error : DS.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.inMinutes.abs() < 60) {
      return diff.isNegative
          ? 'Started ${-diff.inMinutes}m ago'
          : 'In ${diff.inMinutes} min';
    }
    if (diff.inHours.abs() < 24) return 'In ${diff.inHours} hr';
    return '${d.day}/${d.month}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isLive;
  const _StatusBadge({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
      decoration: BoxDecoration(
        color: isLive ? DS.error : DS.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DS.s4),
          ],
          Text(
            isLive ? 'LIVE' : 'Upcoming',
            style: TextStyle(
              color: isLive ? Colors.white : DS.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends ConsumerWidget {
  final Course course;
  final VoidCallback onTap;
  final VoidCallback onContinue;
  const _CourseTile({
    required this.course,
    required this.onTap,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnrolled =
        ref.watch(isEnrolledProvider(course.id)).valueOrNull ?? false;
    final canContinue = isEnrolled || course.isCourseFree;
    final hasThumbnail =
        course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DS.radiusLg),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 11,
                child: hasThumbnail
                    ? CachedNetworkImage(
                        imageUrl: course.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (ctx, url, err) => _ThumbPlaceholder(),
                      )
                    : _ThumbPlaceholder(),
              ),
            ),

            // ── Info ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DS.s10,
                DS.s10,
                DS.s10,
                DS.s10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge chips
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Chip(
                        'Cl. ${course.courseClass}',
                        bg: const Color(0xFFEEF2FF),
                        fg: const Color(0xFF6366F1),
                      ),
                      _Chip(
                        course.target,
                        bg: const Color(0xFFFFF0E6),
                        fg: DS.primary,
                      ),
                      if (course.isCourseFree)
                        _Chip(
                          'Free',
                          bg: const Color(0xFFECFDF5),
                          fg: DS.success,
                        ),
                      if (course.isFeatured)
                        _Chip(
                          'Featured',
                          bg: const Color(0xFFFFFBEB),
                          fg: DS.warning,
                        ),
                    ],
                  ),
                  const SizedBox(height: DS.s8),

                  // Course name
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      letterSpacing: -0.2,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: DS.s8),

                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: canContinue
                              ? [const Color(0xFF34D399), DS.success]
                              : [const Color(0xFFFF8C38), DS.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                        boxShadow: [
                          BoxShadow(
                            color: (canContinue ? DS.success : DS.primary)
                                .withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: canContinue ? onContinue : onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: DS.s8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                        ),
                        icon: Icon(
                          canContinue
                              ? Icons.play_arrow_rounded
                              : Icons.school_rounded,
                          size: 15,
                        ),
                        label: Text(
                          canContinue ? 'Continue' : 'Enroll Now',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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

// ── Recommended courses carousel (2 cards per page) ───────────────────────
class _CoursesCarousel extends StatefulWidget {
  final List<Course> courses;
  final void Function(Course) onTap;
  final void Function(Course) onContinue;

  const _CoursesCarousel({
    required this.courses,
    required this.onTap,
    required this.onContinue,
  });

  @override
  State<_CoursesCarousel> createState() => _CoursesCarouselState();
}

class _CoursesCarouselState extends State<_CoursesCarousel> {
  final _ctrl = PageController();
  int _page = 0;

  // Group the flat list into pairs: [[c0,c1],[c2,c3],…]
  List<List<Course>> get _pages {
    final pages = <List<Course>>[];
    for (var i = 0; i < widget.courses.length; i += 2) {
      pages.add(
        widget.courses.sublist(i, (i + 2).clamp(0, widget.courses.length)),
      );
    }
    return pages;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: _ctrl,
            itemCount: pages.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final pair = pages[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CourseTile(
                          course: pair[0],
                          onTap: () => onTap(pair[0]),
                          onContinue: () => onContinue(pair[0]),
                        ),
                      ),
                      if (pair.length > 1) ...[
                        const SizedBox(width: DS.s10),
                        Expanded(
                          child: _CourseTile(
                            course: pair[1],
                            onTap: () => onTap(pair[1]),
                            onContinue: () => onContinue(pair[1]),
                          ),
                        ),
                      ] else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (pages.length > 1) ...[
          const SizedBox(height: DS.s12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pages.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? DS.primary : DS.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
          const SizedBox(height: DS.s4),
        ],
      ],
    );
  }

  void onTap(Course c) => widget.onTap(c);
  void onContinue(Course c) => widget.onContinue(c);
}

class _ThumbPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: DS.surfaceVariant,
    child: const Center(
      child: Icon(Icons.menu_book_rounded, color: DS.primary, size: 36),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip(this.label, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}
