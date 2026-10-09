import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    (route: '/home', icon: LucideIcons.house, label: 'Home'),
    (route: '/courses', icon: LucideIcons.bookOpen, label: 'Learn'),
    (route: '/tests', icon: LucideIcons.clipboardList, label: 'Tests'),
    (route: '/store', icon: LucideIcons.archive, label: 'Store'),
    (route: '/profile', icon: LucideIcons.user, label: 'Profile'),
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
              child: Image.asset(
                'assets/images/bansal-logo.webp',
                height: 30,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
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
// ─────────────────────────────────────────────
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
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
    final color = isActive ? AppColors.ink : AppColors.textSoft;
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: 54,
              height: 38,
              decoration: BoxDecoration(
                color: isActive ? AppColors.navActive : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
