import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/data/auth_repository.dart';
import '../profile/data/profile_providers.dart';
import '../../core/providers.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

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
    (
      route: '/home',
      iconOff: Icons.home_outlined,
      iconOn: Icons.home_rounded,
      label: 'Home',
    ),
    (
      route: '/courses',
      iconOff: Icons.menu_book_outlined,
      iconOn: Icons.menu_book_rounded,
      label: 'Course',
    ),
    (
      route: '/store',
      iconOff: Icons.storefront_outlined,
      iconOn: Icons.storefront_rounded,
      label: 'Store',
    ),
    (
      route: '/tests',
      iconOff: Icons.assignment_outlined,
      iconOn: Icons.assignment_rounded,
      label: 'Tests',
    ),
    (
      route: '/profile',
      iconOff: Icons.person_outline,
      iconOn: Icons.person_rounded,
      label: 'Profile',
    ),
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
        child: Scaffold(
          key: _scaffoldKey,
          backgroundColor: DS.background,

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
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM APP BAR
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
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s16,
            vertical: DS.s10,
          ),
          child: Row(
            children: [
              // ── Logo ──
              Expanded(
                child: Image.asset(
                  'assets/images/bansal-logo.webp',
                  height: 34,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),

              // ── Action buttons ──
              _NotificationButton(onTap: onNotifications),
              const SizedBox(width: DS.s8),
              _AvatarButton(
                initials: initials,
                avatarUrl: avatarUrl,
                onTap: onOpenDrawer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AVATAR BUTTON (opens dashboard drawer)
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

  @override
  Widget build(BuildContext context) {
    final hasImage = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Tooltip(
      message: 'My Dashboard',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: DS.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: hasImage
              ? Image.network(
                  avatarUrl!,
                  width: 38,
                  height: 38,
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
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION BUTTON (with badge)
// ─────────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                border: Border.all(color: DS.border, width: 1),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 18,
                color: DS.textSecondary,
              ),
            ),
            // Unread dot badge
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: DS.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: DS.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BOTTOM NAVIGATION BAR
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<({String route, IconData iconOff, IconData iconOn, String label})>
  tabs;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: i == 2
                    ? _RaisedStoreNavItem(
                        icon: isActive ? tab.iconOn : tab.iconOff,
                        label: tab.label,
                        isActive: isActive,
                        onTap: () => onTap(i),
                      )
                    : _NavItem(
                        icon: isActive ? tab.iconOn : tab.iconOff,
                        label: tab.label,
                        isActive: isActive,
                        isLive: false,
                        onTap: () => onTap(i),
                      ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _RaisedStoreNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RaisedStoreNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: -18,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isActive ? DS.primary : DS.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? DS.primaryLight : DS.border,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: DS.primary.withValues(alpha: isActive ? 0.28 : 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 25,
                color: isActive ? Colors.white : DS.primary,
              ),
            ),
          ),
          Positioned(
            bottom: 3,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isActive ? DS.primary : DS.textSecondary,
              ),
            ),
          ),
        ],
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
  final bool isLive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isLive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with active pill indicator
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Active pill background
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isActive ? 44 : 38,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? DS.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
              ),

              // Icon
              Icon(
                icon,
                size: 22,
                color: isActive ? DS.primary : DS.textSecondary,
              ),

              // Live pulsing dot
              if (isLive && !isActive)
                Positioned(
                  top: 0,
                  right: 6,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: DS.s4),

          // Label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? DS.primary : DS.textSecondary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
