import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/live_providers.dart';
import 'data/models/live_class.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);
  static const accent = Color(0xFFFF7A00);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFFFBEB);

  static const double s3 = 3;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// Subject → gradient colors, matching the web app's subjectColors map.
const Map<String, List<Color>> _subjectColors = {
  'Physics': [Color(0xFF3B82F6), Color(0xFF2563EB)],
  'Chemistry': [Color(0xFF22C55E), Color(0xFF16A34A)],
  'Mathematics': [Color(0xFFA855F7), Color(0xFF9333EA)],
  'Biology': [Color(0xFFEC4899), Color(0xFFDB2777)],
};

List<Color> _colorsFor(String subject) =>
    _subjectColors[subject] ?? const [DS.primary, DS.accent];

// ─────────────────────────────────────────────
// LIVE LIST SCREEN
// ─────────────────────────────────────────────
class LiveListScreen extends ConsumerWidget {
  const LiveListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accessibleLiveClassesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: DS.background,
          body: SafeArea(
            child: async.when(
              loading: () => const _LoadingState(),
              error: (e, _) => _ErrorState(
                message: 'Failed to load: $e',
                onRetry: () => ref.invalidate(accessibleLiveClassesProvider),
              ),
              data: (classes) {
                final now = DateTime.now();
                final live = classes.where((c) => c.isLive).toList();
                final upcoming =
                    classes
                        .where(
                          (c) =>
                              c.status == 'scheduled' &&
                              c.startsAt.isAfter(now),
                        )
                        .toList()
                      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

                return RefreshIndicator(
                  color: DS.primary,
                  onRefresh: () async {
                    ref.invalidate(accessibleLiveClassesProvider);
                    await ref.read(accessibleLiveClassesProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s16,
                      DS.s16,
                      DS.s16,
                      DS.s32,
                    ),
                    children: [
                      _LiveHero(liveCount: live.length, upcomingCount: upcoming.length),

                      if (live.isNotEmpty) ...[
                        const SizedBox(height: DS.s24),
                        const _SectionLabel('Live now'),
                        const SizedBox(height: DS.s12),
                        _LiveNowGrid(items: live),
                      ],

                      const SizedBox(height: DS.s24),
                      const _SectionLabel('Upcoming'),
                      const SizedBox(height: DS.s12),
                      if (upcoming.isEmpty)
                        const _EmptyUpcoming()
                      else
                        _UpcomingList(items: upcoming),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO — gradient card with Live now / Upcoming stat pills
// ─────────────────────────────────────────────
class _LiveHero extends StatelessWidget {
  final int liveCount;
  final int upcomingCount;
  const _LiveHero({required this.liveCount, required this.upcomingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DS.primary, DS.accent, DS.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusXl),
        boxShadow: [
          BoxShadow(
            color: DS.primary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 26),
              const SizedBox(width: DS.s10),
              const Text(
                'Live Classes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s8),
          Text(
            'Join interactive sessions with top educators in real-time',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.90),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: DS.s16),
          Row(
            children: [
              _StatPill(value: liveCount, label: 'Live now'),
              const SizedBox(width: DS.s12),
              _StatPill(value: upcomingCount, label: 'Upcoming'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final int value;
  final String label;
  const _StatPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: DS.textPrimary,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIVE NOW — grid of cards
// ─────────────────────────────────────────────
class _LiveNowGrid extends StatelessWidget {
  final List<LiveClass> items;
  const _LiveNowGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: DS.s12,
        crossAxisSpacing: DS.s12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) => _LiveNowCard(lc: items[i]),
    );
  }
}

class _LiveNowCard extends StatelessWidget {
  final LiveClass lc;
  const _LiveNowCard({required this.lc});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(lc.subject);
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/live/${lc.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white.withValues(alpha: 0.40),
                        size: 40,
                      ),
                    ),
                  ),
                  const Positioned(top: DS.s10, left: DS.s10, child: _LiveBadge()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DS.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lc.subject.toUpperCase(),
                    style: const TextStyle(
                      color: DS.primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lc.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DS.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lc.educatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: DS.s10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        context.push('/live/${lc.id}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DS.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: DS.s8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 14),
                      label: const Text(
                        'Join Now',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _blink = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s3),
      decoration: BoxDecoration(
        color: DS.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _blink,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: DS.s4),
          const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// UPCOMING — simple list
// ─────────────────────────────────────────────
class _UpcomingList extends StatelessWidget {
  final List<LiveClass> items;
  const _UpcomingList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: DS.s10),
          _UpcomingRow(lc: items[i]),
        ],
      ],
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final LiveClass lc;
  const _UpcomingRow({required this.lc});

  @override
  Widget build(BuildContext context) {
    final colors = _colorsFor(lc.subject);
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/live/${lc.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lc.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DS.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${lc.educatorName} · ${lc.subject}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: DS.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: DS.s4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 11, color: DS.textHint),
                      const SizedBox(width: DS.s4),
                      Text(
                        _formatDate(lc.startsAt),
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
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

  static String _formatDate(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classDay = DateTime(local.year, local.month, local.day);
    final diffDays = classDay.difference(today).inDays;
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    if (diffDays == 0) return 'Today, $h:$m';
    if (diffDays == 1) return 'Tomorrow, $h:$m';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, $h:$m';
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'No upcoming classes scheduled.',
      style: TextStyle(color: DS.textSecondary, fontSize: 12.5),
    );
  }
}

// ─────────────────────────────────────────────
// LOADING STATE
// ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
  );
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 32,
              ),
            ),
            const SizedBox(height: DS.s16),
            Text(
              message,
              style: const TextStyle(color: DS.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s20),
            SizedBox(
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [DS.primary, DS.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
