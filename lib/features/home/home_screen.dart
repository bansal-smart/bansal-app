import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../skeleton_loading/home_skeleton.dart';
import '../profile/data/dashboard_stats_providers.dart';
import '../courses/data/courses_providers.dart';
import '../live/data/live_providers.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';
import 'data/landing_hero_banners_provider.dart';
import 'widgets/landing_banner_carousel.dart';

abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFF7F8FA);
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
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(accessibleLiveClassesProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final enrollmentsAsync = ref.watch(enrollmentsProvider);
    final testsCompletedAsync = ref.watch(testsCompletedProvider);
    final streakAsync = ref.watch(streakProvider);
    final accuracyAsync = ref.watch(accuracyProvider);
    final airPercentileAsync = ref.watch(airPercentileProvider);
    final bannersAsync = ref.watch(landingHeroBannersProvider);
    final showSkeleton =
        liveAsync.isLoading &&
        coursesAsync.isLoading &&
        enrollmentsAsync.isLoading;

    if (showSkeleton) return const HomeSkeleton();

    final enrollments = enrollmentsAsync.valueOrNull ?? const <Enrollment>[];
    final hasEnrollment = enrollments.isNotEmpty;
    final recentEnrollment = hasEnrollment
        ? ([...enrollments]..sort((a, b) {
            final aTime = a.lastAccessedAt ?? a.createdAt;
            final bTime = b.lastAccessedAt ?? b.createdAt;
            return bTime.compareTo(aTime);
          })).first
        : null;

    final testsCompleted = testsCompletedAsync.valueOrNull ?? 0;
    final streak = streakAsync.valueOrNull ?? 0;
    final accuracy = accuracyAsync.valueOrNull;
    final airPercentile = airPercentileAsync.valueOrNull;

    final todaysLive =
        liveAsync.valueOrNull
            ?.where((c) => !c.isPast && _isToday(c.startsAt))
            .toList() ??
        const [];

    return ColoredBox(
      color: DS.background,
      child: RefreshIndicator(
        color: DS.primary,
        onRefresh: () async {
          ref.invalidate(accessibleLiveClassesProvider);
          ref.invalidate(coursesProvider);
          ref.invalidate(enrollmentsProvider);
          ref.invalidate(testsCompletedProvider);
          ref.invalidate(streakProvider);
          ref.invalidate(accuracyProvider);
          ref.invalidate(airPercentileProvider);
          ref.invalidate(landingHeroBannersProvider);
          await Future.wait([
            ref.read(accessibleLiveClassesProvider.future),
            ref.read(coursesProvider.future),
            ref.read(enrollmentsProvider.future),
            ref.read(landingHeroBannersProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DS.s16,
            DS.s16,
            DS.s16,
            DS.s32,
          ),
          children: [
            // Same admin-managed carousel used by the website hero.
            bannersAsync.when(
              data: (banners) => LandingBannerCarousel(banners: banners),
              loading: () => const _BannerLoadingPlaceholder(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            if (bannersAsync.valueOrNull?.isNotEmpty == true ||
                bannersAsync.isLoading)
              const SizedBox(height: DS.s16),

            // ── Quick action grid ──
            _QuickActionsGrid(
              onMyCourse: () => context.go('/courses'),
              onLiveClass: () => context.go('/live'),
              onLiveTest: () => context.go('/tests'),
              onMyProgress: () => context.go('/profile'),
            ),

            const SizedBox(height: DS.s24),

            // ── My Progress ──
            _SectionHeader(
              title: 'My Progress',
              subtitle: "Snapshot of how you're tracking right now",
              actionLabel: 'View details',
              onAction: () => context.go('/profile'),
            ),
            const SizedBox(height: DS.s12),
            _ProgressGrid(
              testsCompleted: testsCompleted,
              streak: streak,
              accuracy: accuracy,
              airPercentile: airPercentile,
            ),

            const SizedBox(height: DS.s24),

            // ── Today ──
            _SectionHeader(
              title: 'Today',
              subtitle: 'Live classes & tests',
              actionLabel: 'All',
              onAction: () => context.go('/live'),
            ),
            const SizedBox(height: DS.s12),
            _TodayCard(hasClasses: todaysLive.isNotEmpty),

            const SizedBox(height: DS.s24),

            // ── Continue Learning ──
            _SectionHeader(
              title: 'Continue Learning',
              subtitle: 'Jump back into your courses',
              actionLabel: 'All courses',
              onAction: () => context.go('/courses'),
            ),
            const SizedBox(height: DS.s12),
            _ContinueLearningCard(
              enrollment: recentEnrollment,
              onOpenCourse: () => recentEnrollment != null
                  ? context.push('/my-courses/${recentEnrollment.courseId}')
                  : context.go('/courses'),
            ),
          ],
        ),
      ),
    );
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _BannerLoadingPlaceholder extends StatelessWidget {
  const _BannerLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: Container(
        decoration: BoxDecoration(
          color: DS.primaryLight,
          borderRadius: BorderRadius.circular(DS.radiusLg),
        ),
        alignment: Alignment.center,
        child: const SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

// ── Quick actions grid ───────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onMyCourse;
  final VoidCallback onLiveClass;
  final VoidCallback onLiveTest;
  final VoidCallback onMyProgress;

  const _QuickActionsGrid({
    required this.onMyCourse,
    required this.onLiveClass,
    required this.onLiveTest,
    required this.onMyProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.menu_book_rounded,
                title: 'My Course',
                subtitle: 'Study material',
                onTap: onMyCourse,
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: _ActionTile(
                icon: Icons.videocam_rounded,
                title: 'Live Class',
                subtitle: 'Join live sessions',
                onTap: onLiveClass,
              ),
            ),
          ],
        ),
        const SizedBox(height: DS.s12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.assignment_rounded,
                title: 'Live Test',
                subtitle: 'Take a test',
                onTap: onLiveTest,
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: _ActionTile(
                icon: Icons.bar_chart_rounded,
                title: 'My Progress',
                subtitle: 'Detailed analytics',
                onTap: onMyProgress,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(DS.s16),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: DS.border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: Icon(icon, color: DS.primary, size: 20),
            ),
            const SizedBox(height: DS.s12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11.5,
                color: DS.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header (shared) ─────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: DS.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: DS.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.only(left: DS.s8, top: 2),
              child: Text(
                '$actionLabel →',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: DS.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── My Progress stat grid ────────────────────────────────────────────────────
class _ProgressGrid extends StatelessWidget {
  final int testsCompleted;
  final int streak;
  final int? accuracy;
  final double? airPercentile;

  const _ProgressGrid({
    required this.testsCompleted,
    required this.streak,
    required this.accuracy,
    required this.airPercentile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                iconColor: const Color(0xFFF59E0B),
                value: '$streak ${streak == 1 ? 'day' : 'days'}',
                label: 'Current Streak',
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: _StatTile(
                icon: Icons.track_changes_rounded,
                iconColor: const Color(0xFFFB923C),
                value: accuracy != null ? '$accuracy%' : '—',
                label: 'Overall Accuracy',
              ),
            ),
          ],
        ),
        const SizedBox(height: DS.s12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.assignment_turned_in_rounded,
                iconColor: const Color(0xFFF59E0B),
                value: '$testsCompleted',
                label: 'Tests Completed',
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFEAB308),
                value: airPercentile != null ? '$airPercentile%ile' : '—',
                label: 'AIR Percentile',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: DS.s10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: DS.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Today card (empty / list) ────────────────────────────────────────────────
class _TodayCard extends StatelessWidget {
  final bool hasClasses;
  const _TodayCard({required this.hasClasses});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DS.s16,
        vertical: DS.s28,
      ),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 30,
            color: DS.textHint,
          ),
          const SizedBox(height: DS.s10),
          const Text(
            'No classes today',
            style: TextStyle(fontSize: 13.5, color: DS.textSecondary),
          ),
          const SizedBox(height: DS.s4),
          GestureDetector(
            onTap: () => GoRouter.of(context).go('/live'),
            child: const Text(
              'Browse schedule',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DS.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continue Learning card ───────────────────────────────────────────────────
class _ContinueLearningCard extends StatelessWidget {
  final Enrollment? enrollment;
  final VoidCallback onOpenCourse;

  const _ContinueLearningCard({
    required this.enrollment,
    required this.onOpenCourse,
  });

  @override
  Widget build(BuildContext context) {
    if (enrollment == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s28,
        ),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: DS.border, width: 1.2),
        ),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 30, color: DS.textHint),
            const SizedBox(height: DS.s10),
            const Text(
              'Nothing in progress yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s4),
            const Text(
              'Open My Course to start your first lesson.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: DS.textSecondary),
            ),
            const SizedBox(height: DS.s16),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onOpenCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: DS.s20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text(
                  'Open My Course',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onOpenCourse,
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: DS.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(Icons.menu_book_rounded, color: DS.primary),
            ),
            const SizedBox(width: DS.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enrollment!.courseTitle ?? 'Course',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DS.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Continue where you left off',
                    style: TextStyle(fontSize: 12, color: DS.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: DS.textHint),
          ],
        ),
      ),
    );
  }
}
