import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../auth/data/auth_repository.dart';
import '../profile/data/profile_providers.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/app_background.dart';

// ─────────────────────────────────────────────
// HOME SHELL
// ─────────────────────────────────────────────
class HomeShell extends ConsumerStatefulWidget {
  final Widget child;
  final String location;

  const HomeShell({super.key, required this.child, required this.location});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _tabs = [
    (route: '/home', icon: LucideIcons.house300, label: 'Home'),
    (route: '/courses', icon: LucideIcons.bookOpen300, label: 'Learn'),
    (route: '/tests', icon: LucideIcons.clipboardList300, label: 'Tests'),
    (route: '/store', icon: LucideIcons.archive300, label: 'Store'),
    (route: '/profile', icon: LucideIcons.user300, label: 'Profile'),
  ];

  int get _index => _tabs
      .indexWhere((t) => widget.location.startsWith(t.route))
      .clamp(0, _tabs.length - 1);

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authRepositoryProvider).currentUser();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final setupInfo = ref.watch(profileSetupInfoProvider);
    final displayName = profile?.fullName?.trim().isNotEmpty == true
        ? profile!.fullName!.trim()
        : setupInfo.name.isNotEmpty
        ? setupInfo.name
        : (user?.name?.trim().isNotEmpty == true
              ? user!.name!.trim()
              : 'Learner');
    final initials = _initials(displayName);
    final avatarUrl = profile?.avatarUrl ?? user?.avatarUrl;
    final currentIdx = _index;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: widget.location == '/home',
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && widget.location != '/home') {
            context.go('/home');
          }
        },
        child: AppBackground(
          // The bubbles fade in (as in bg_screen.mp4) when the app opens and
          // replay on every tab switch, as in reference_video.mp4.
          introKey: _tabs[currentIdx].route,
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,

            // ── Top App Bar ──
            appBar: _AppBar(
              initials: initials,
              avatarUrl: avatarUrl,
              onNotifications: () => context.push('/notifications'),
              onOpenDrawer: () {
                if (widget.location != '/profile') context.go('/profile');
              },
            ),

            body: widget.child,

            // ── Bottom Navigation ──
            bottomNavigationBar: _BottomNav(
              currentIndex: currentIdx,
              onTap: (i) {
                HapticFeedback.selectionClick();
                context.go(_tabs[i].route);
              },
              tabs: _tabs,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM APP BAR (sits directly on the background)
// ─────────────────────────────────────────────
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String initials;
  final String? avatarUrl;
  final VoidCallback onNotifications;
  final VoidCallback onOpenDrawer;

  const _AppBar({
    required this.initials,
    this.avatarUrl,
    required this.onNotifications,
    required this.onOpenDrawer,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Row(
          children: [
            // ── Logo ──
            Expanded(
              child: _LogoEntrance(
                child: Image.asset(
                  'assets/images/bansal-logo.webp',
                  height: 30,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),

            // ── Action buttons ──
            _NotificationButton(onTap: onNotifications),
            const SizedBox(width: 14),
            _AvatarButton(
              initials: initials,
              avatarUrl: avatarUrl,
              onTap: onOpenDrawer,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGO ENTRANCE — slides in from the left once, when the shell first appears
// (the shell persists across tabs, so switching tabs doesn't replay it).
// ─────────────────────────────────────────────
class _LogoEntrance extends StatelessWidget {
  final Widget child;
  const _LogoEntrance({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return child
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideX(
          begin: -0.25,
          end: 0,
          duration: 500.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────
// AVATAR BUTTON (opens dashboard)
// ─────────────────────────────────────────────
class _AvatarButton extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final VoidCallback onTap;
  const _AvatarButton({
    required this.initials,
    this.avatarUrl,
    required this.onTap,
  });

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Tooltip(
      message: 'My Dashboard',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _size,
          height: _size,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: hasImage
              ? Image.network(
                  avatarUrl!,
                  width: _size,
                  height: _size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _InitialsText(initials),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _InitialsText(initials);
                  },
                )
              : _InitialsText(initials),
        ),
      ),
    );
  }
}

class _InitialsText extends StatelessWidget {
  final String initials;
  const _InitialsText(this.initials);

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION BUTTON
// ─────────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: onTap,
      icon: const Icon(LucideIcons.bell, size: 26, color: AppColors.ink),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM NAVIGATION BAR
// One shared highlight pill slides to the selected tab (as in the reference
// video), and the newly selected icon gives a small bounce.
// ─────────────────────────────────────────────
/// Sizes taken from the nav-bar reference image. Content height is
/// 6 + 40 + 5 + 16 = 67, inside the 72px bar, so nothing can overflow.
abstract class _NavMetrics {
  static const double barHeight = 72;
  static const double topInset = 6;
  static const double pillWidth = 60;
  static const double pillHeight = 40;
  static const double labelGap = 5;
  static const double labelHeight = 16;
  static const double iconSize = 24;
  static const slide = Duration(milliseconds: 300);

  /// Active: navy icon + bold navy label. Inactive: muted grey (#6B7280,
  /// ~4.8:1 on white).
  static const active = AppColors.primary;
  static const inactive = AppColors.textSoft;
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<({String route, IconData icon, String label})> tabs;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Container(
      // Clean white bar: hairline top border plus a very soft upward shadow.
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFEDEFF3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _NavMetrics.barHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / tabs.length;
              return Stack(
                children: [
                  // The pill sits behind the icons and slides between slots
                  // smoothly. (No overshoot: on long jumps such as Home →
                  // Profile a springy curve would push it past the bar edge;
                  // the icon bounce supplies the spring feel instead.)
                  AnimatedPositioned(
                    duration: reduceMotion ? Duration.zero : _NavMetrics.slide,
                    curve: Curves.easeOutCubic,
                    top: _NavMetrics.topInset,
                    left:
                        slotWidth * currentIndex +
                        (slotWidth - _NavMetrics.pillWidth) / 2,
                    width: _NavMetrics.pillWidth,
                    height: _NavMetrics.pillHeight,
                    // Stadium-shaped pill with the soft drop shadow from the
                    // reference image.
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.navActive,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x2E1E293B),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(tabs.length, (i) {
                      final tab = tabs[i];
                      return Expanded(
                        child: _NavItem(
                          icon: tab.icon,
                          label: tab.label,
                          isActive: i == currentIndex,
                          onTap: () => onTap(i),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SINGLE NAV ITEM
// ─────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Navy icon + bold label when active, muted grey otherwise.
    final color = isActive ? _NavMetrics.active : _NavMetrics.inactive;
    Widget iconWidget = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 200),
      builder: (_, c, _) => Icon(icon, size: _NavMetrics.iconSize, color: c),
    );
    // A new Animate subtree is mounted when the tab becomes active, so the
    // bounce plays once per selection (not on unrelated rebuilds).
    if (isActive && !MediaQuery.of(context).disableAnimations) {
      iconWidget = iconWidget
          .animate(key: ValueKey('nav-active-$label'))
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 200.ms,
            curve: Curves.easeOutBack,
          );
    }

    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Fixed geometry so every icon centres exactly inside the sliding
        // pill: inset, pill-height icon slot, gap, then the label.
        child: Column(
          children: [
            const SizedBox(height: _NavMetrics.topInset),
            SizedBox(
              height: _NavMetrics.pillHeight,
              child: Center(child: iconWidget),
            ),
            const SizedBox(height: _NavMetrics.labelGap),
            SizedBox(
              height: _NavMetrics.labelHeight,
              // Shrinks instead of overflowing with large system font sizes.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
