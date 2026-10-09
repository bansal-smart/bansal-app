import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../skeleton_loading/home_skeleton.dart';
import '../auth/data/auth_repository.dart';
import '../profile/data/dashboard_stats_providers.dart';
import '../profile/data/profile_providers.dart';
import '../courses/data/courses_providers.dart';
import '../live/data/live_providers.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';
import 'data/landing_hero_banners_provider.dart';
import 'widgets/landing_banner_carousel.dart';

abstract class DS {
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

  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 26;

  /// Soft drop shadow used by every floating card in the Figma design.
  static const cardShadow = [
    BoxShadow(color: Color(0x14102A5C), blurRadius: 18, offset: Offset(0, 6)),
  ];
}

/// Entrance motion modelled on the Figma prototype video: each section fades
/// in while rising a short distance, one after another; card contents (icons,
/// chart bars, progress fill, numbers) settle in just after their card.
abstract class _Motion {
  /// Gap between consecutive sections.
  static const step = Duration(milliseconds: 90);
  static const duration = Duration(milliseconds: 450);
  static const rise = Offset(0, 24);

  /// Start time of the section at [order] in the stagger.
  static Duration at(int order) => step * order;

  /// Honour the system "remove animations" accessibility setting.
  static bool off(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;
}

extension _Entrance on Widget {
  /// Fade-in + slide-up, staggered by [order].
  Widget entrance(BuildContext context, int order) {
    if (_Motion.off(context)) return this;
    return animate(delay: _Motion.at(order))
        .fadeIn(duration: _Motion.duration, curve: Curves.easeOut)
        .move(
          begin: _Motion.rise,
          end: Offset.zero,
          duration: _Motion.duration,
          curve: Curves.easeOutCubic,
        );
  }

  /// Plain fade used for details inside a card once the card has arrived.
  Widget reveal(BuildContext context, Duration delay, {int ms = 350}) {
    if (_Motion.off(context)) return this;
    return animate(delay: delay).fadeIn(
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOut,
    );
  }
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
    final weeklyAsync = ref.watch(weeklyStudyMinutesProvider);
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
              }))
              .first
        : null;

    final testsCompleted = testsCompletedAsync.valueOrNull ?? 0;
    final streak = streakAsync.valueOrNull ?? 0;
    final accuracy = accuracyAsync.valueOrNull;
    final weeklyMinutes = weeklyAsync.valueOrNull ?? List<int>.filled(7, 0);

    final todaysLive =
        liveAsync.valueOrNull
            ?.where((c) => !c.isPast && _isToday(c.startsAt))
            .toList() ??
        const [];

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(accessibleLiveClassesProvider);
        ref.invalidate(coursesProvider);
        ref.invalidate(enrollmentsProvider);
        ref.invalidate(testsCompletedProvider);
        ref.invalidate(streakProvider);
        ref.invalidate(accuracyProvider);
        ref.invalidate(weeklyStudyMinutesProvider);
        ref.invalidate(landingHeroBannersProvider);
        await Future.wait([
          ref.read(accessibleLiveClassesProvider.future),
          ref.read(coursesProvider.future),
          ref.read(enrollmentsProvider.future),
          ref.read(landingHeroBannersProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(DS.s20, DS.s4, DS.s20, DS.s32),
        // The number passed to entrance() is each section's place in the
        // stagger (see _Motion); the list length stays fixed so animation
        // state never shifts onto a neighbouring section.
        children: [
          // ── Greeting ──
          _Greeting(firstName: _firstName(ref)).entrance(context, 0),
          const SizedBox(height: DS.s16),

          // Same admin-managed carousel used by the website hero.
          bannersAsync
              .when(
                data: (banners) => LandingBannerCarousel(banners: banners),
                loading: () => const _BannerLoadingPlaceholder(),
                error: (_, _) => const SizedBox.shrink(),
              )
              .entrance(context, 1),

          SizedBox(
            height:
                bannersAsync.valueOrNull?.isNotEmpty == true ||
                    bannersAsync.isLoading
                ? DS.s20
                : 0,
          ),

          // ── Momentum ──
          _MomentumCard(
            streak: streak,
            testsCompleted: testsCompleted,
            accuracy: accuracy,
            revealAt: _Motion.at(2),
            onTap: () => context.go('/profile'),
          ).entrance(context, 2),

          const SizedBox(height: DS.s28),

          // ── Quick access ──
          const _SectionHeader(title: 'Quick Access').entrance(context, 3),
          const SizedBox(height: DS.s14),
          Row(
            children: [
              Expanded(
                child: _QuickAccessTile(
                  icon: LucideIcons.bookOpen200,
                  label: 'My courses',
                  color: AppColors.tileBlue,
                  revealAt: _Motion.at(4),
                  onTap: () => context.go('/courses'),
                ).entrance(context, 4),
              ),
              const SizedBox(width: DS.s14),
              Expanded(
                child: _QuickAccessTile(
                  icon: LucideIcons.clipboardList200,
                  label: 'My Test',
                  color: AppColors.tileLavender,
                  revealAt: _Motion.at(5),
                  onTap: () => context.go('/tests'),
                ).entrance(context, 5),
              ),
            ],
          ),

          const SizedBox(height: DS.s28),

          // ── Weekly progress ──
          _SectionHeader(
            title: 'Weekly Progress',
            actionLabel: 'Details',
            onAction: () => context.go('/profile'),
          ).entrance(context, 6),
          const SizedBox(height: DS.s14),
          _WeeklyProgressCard(
            minutes: weeklyMinutes,
            revealAt: _Motion.at(7),
          ).entrance(context, 7),

          const SizedBox(height: DS.s28),

          // ── Today ──
          _SectionHeader(
            title: 'Today',
            actionLabel: 'All',
            onAction: () => context.go('/live'),
          ).entrance(context, 8),
          const SizedBox(height: DS.s14),
          _TodayCard(hasClasses: todaysLive.isNotEmpty).entrance(context, 9),

          const SizedBox(height: DS.s28),

          // ── Continue Learning ──
          _SectionHeader(
            title: 'Continue Learning',
            actionLabel: 'All courses',
            onAction: () => context.go('/courses'),
          ).entrance(context, 10),
          const SizedBox(height: DS.s14),
          _ContinueLearningCard(
            enrollment: recentEnrollment,
            onOpenCourse: () => recentEnrollment != null
                ? context.push('/my-courses/${recentEnrollment.courseId}')
                : context.go('/courses'),
          ).entrance(context, 11),
        ],
      ),
    );
  }

  /// Same name resolution as the shell's avatar, reduced to the first name.
  static String _firstName(WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final setupInfo = ref.watch(profileSetupInfoProvider);
    final name = profile?.fullName?.trim().isNotEmpty == true
        ? profile!.fullName!.trim()
        : setupInfo.name.isNotEmpty
        ? setupInfo.name
        : (user?.name?.trim() ?? '');
    final first = name
        .split(' ')
        .firstWhere((p) => p.isNotEmpty, orElse: () => 'Learner');
    return first;
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _Greeting extends StatelessWidget {
  final String firstName;
  const _Greeting({required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Welcome, $firstName 👋',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.3,
      ),
    );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          boxShadow: DS.cardShadow,
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

// ── Momentum card ────────────────────────────────────────────────────────────
class _MomentumCard extends StatelessWidget {
  final int streak;
  final int testsCompleted;
  final int? accuracy;

  /// When this card starts its entrance; the progress bar fills after it.
  final Duration revealAt;
  final VoidCallback onTap;

  const _MomentumCard({
    required this.streak,
    required this.testsCompleted,
    required this.accuracy,
    required this.revealAt,
    required this.onTap,
  });

  static const _fill = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    final progress = (accuracy ?? 0) / 100;
    final fillStart = revealAt + const Duration(milliseconds: 500);
    Widget bar(double value) => ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor: const Color(0xFF3D5C9C),
        valueColor: const AlwaysStoppedAnimation(AppColors.orange),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(DS.s20, DS.s20, DS.s20, DS.s24),
        decoration: BoxDecoration(
          color: AppColors.deepNavy,
          borderRadius: BorderRadius.circular(DS.radiusXl),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33102A5C),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'DAY $streak',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Your learning momentum',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: DS.s6),
            Text(
              '$testsCompleted ${testsCompleted == 1 ? 'test' : 'tests'} '
              'completed · overall accuracy',
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: DS.s20),
            Row(
              children: [
                Expanded(
                  flex: 5,
                  // Fills from empty to the current value, like the video.
                  child: _Motion.off(context)
                      ? bar(progress)
                      : bar(0)
                            .animate(delay: fillStart)
                            .custom(
                              duration: _fill,
                              curve: Curves.easeOutCubic,
                              builder: (context, t, _) => bar(progress * t),
                            ),
                ),
                const SizedBox(width: DS.s16),
                Text(
                  accuracy != null ? '$accuracy%' : '—',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ).reveal(context, fillStart + _fill),
                const Spacer(flex: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick access tile ────────────────────────────────────────────────────────
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  /// When this tile starts its entrance; its icon and label follow.
  final Duration revealAt;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.revealAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(DS.radiusLg),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DS.radiusLg),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: DS.cardShadow,
          ),
          // The tile arrives as a soft shell, then its contents fade in.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 46, color: AppColors.ink),
              const SizedBox(height: DS.s8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ).reveal(context, revealAt + const Duration(milliseconds: 220)),
        ),
      ),
    );
  }
}

// ── Section header (shared) ─────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              letterSpacing: 0.3,
            ),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: DS.s8),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Weekly progress card ─────────────────────────────────────────────────────
class _WeeklyProgressCard extends StatelessWidget {
  /// Minutes studied per day, Monday first.
  final List<int> minutes;

  /// When this card starts its entrance; bars and totals follow.
  final Duration revealAt;
  const _WeeklyProgressCard({required this.minutes, required this.revealAt});

  static const _barStagger = Duration(milliseconds: 60);

  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const double _maxBar = 84;
  static const double _minBar = 10;

  String _formatTotal(int total) {
    final h = total ~/ 60;
    final m = total % 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final total = minutes.fold<int>(0, (a, b) => a + b);
    final peak = minutes.fold<int>(0, (a, b) => a > b ? a : b);
    final todayIndex = DateTime.now().weekday - 1;
    final reduceMotion = _Motion.off(context);
    final barsStart = revealAt + const Duration(milliseconds: 150);

    return Container(
      padding: const EdgeInsets.fromLTRB(DS.s20, DS.s20, DS.s16, DS.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DS.radiusXl),
        boxShadow: DS.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatTotal(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ).reveal(context, barsStart + const Duration(milliseconds: 250)),
              const SizedBox(height: DS.s20),
              const Text(
                'Study Time',
                style: TextStyle(fontSize: 10, color: AppColors.textSoft),
              ).reveal(context, barsStart + const Duration(milliseconds: 500)),
            ],
          ),
          const SizedBox(width: DS.s16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: DS.s24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final ratio = peak == 0 ? 0.0 : minutes[i] / peak;
                  final height = _minBar + (_maxBar - _minBar) * ratio;
                  final bar = AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: 15,
                    height: height,
                    decoration: BoxDecoration(
                      color: i == todayIndex
                          ? AppColors.orange
                          : AppColors.barIdle,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  );
                  return Semantics(
                    label: '${_days[i]}: ${_formatTotal(minutes[i])}',
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Bars rise from the baseline one after another.
                        if (reduceMotion)
                          bar
                        else
                          bar
                              .animate(delay: barsStart + _barStagger * i)
                              .fadeIn(duration: 250.ms)
                              .scaleY(
                                begin: 0,
                                end: 1,
                                alignment: Alignment.bottomCenter,
                                duration: 500.ms,
                                curve: Curves.easeOutCubic,
                              ),
                        const SizedBox(height: DS.s10),
                        Text(
                          _days[i],
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSoft,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared white card ────────────────────────────────────────────────────────
class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _WhiteCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DS.radiusXl),
        boxShadow: DS.cardShadow,
      ),
      child: child,
    );
  }
}

// ── Today card (empty / list) ────────────────────────────────────────────────
class _TodayCard extends StatelessWidget {
  final bool hasClasses;
  const _TodayCard({required this.hasClasses});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s24),
      child: Column(
        children: [
          const Icon(LucideIcons.calendar, size: 28, color: AppColors.barIdle),
          const SizedBox(height: DS.s10),
          const Text(
            'No classes today',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSoft),
          ),
          const SizedBox(height: DS.s4),
          GestureDetector(
            onTap: () => GoRouter.of(context).go('/live'),
            child: const Text(
              'Browse schedule',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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
      return _WhiteCard(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s24,
        ),
        child: Column(
          children: [
            const Icon(
              LucideIcons.sparkles,
              size: 28,
              color: AppColors.barIdle,
            ),
            const SizedBox(height: DS.s10),
            const Text(
              'Nothing in progress yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: DS.s4),
            const Text(
              'Open My Course to start your first lesson.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSoft),
            ),
            const SizedBox(height: DS.s16),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: onOpenCourse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: DS.s20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(LucideIcons.arrowRight, size: 16),
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
      child: _WhiteCard(
        padding: const EdgeInsets.all(DS.s14),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.tileBlue,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(LucideIcons.bookOpen, color: AppColors.ink),
            ),
            const SizedBox(width: DS.s14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enrollment!.courseTitle ?? 'Course',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Continue where you left off',
                    style: TextStyle(fontSize: 12, color: AppColors.textSoft),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: AppColors.textSoft,
            ),
          ],
        ),
      ),
    );
  }
}
