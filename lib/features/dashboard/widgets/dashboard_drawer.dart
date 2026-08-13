import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
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
  static const errorSurface = Color(0xFFFEF2F2);

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
// DRAWER ITEM MODEL
// ─────────────────────────────────────────────
class _DrawerItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _DrawerItem(this.icon, this.label, this.route, this.color);
}

class _DrawerSection {
  final String title;
  final List<_DrawerItem> items;
  const _DrawerSection(this.title, this.items);
}

// ─────────────────────────────────────────────
// DASHBOARD DRAWER
// ─────────────────────────────────────────────
class DashboardDrawer extends StatefulWidget {
  final bool fromRight;
  const DashboardDrawer({super.key, this.fromRight = false});

  @override
  State<DashboardDrawer> createState() => _DashboardDrawerState();
}

class _DashboardDrawerState extends State<DashboardDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<Offset>> _slides;
  late List<Animation<double>> _fades;

  static const _shellRoutes = {
    '/home',
    '/courses',
    '/live',
    '/tests',
    '/profile',
  };

  static final _sections = [
    _DrawerSection('Main', [
      _DrawerItem(
        Icons.dashboard_rounded,
        'Home',
        '/student-dashboard',
        const Color(0xFFF97315),
      ),
      _DrawerItem(
        Icons.menu_book_outlined,
        'My Learning',
        '/my-learning',
        const Color(0xFF6366F1),
      ),
      _DrawerItem(
        Icons.psychology_outlined,
        'Doubts',
        '/doubts',
        const Color(0xFF06B6D4),
      ),
      _DrawerItem(
        Icons.chat_bubble_outline,
        'Mentor Chat',
        '/mentor-chat',
        const Color(0xFF8B5CF6),
      ),
      _DrawerItem(
        Icons.live_tv_outlined,
        'Live Classes',
        '/live',
        const Color(0xFFEF4444),
      ),
    ]),
    _DrawerSection('Explore', [
      _DrawerItem(
        Icons.flash_on_outlined,
        'Compete',
        '/compete',
        const Color(0xFFEF4444),
      ),
      _DrawerItem(
        Icons.insights_outlined,
        'Analytics',
        '/analytics',
        const Color(0xFF10B981),
      ),
      _DrawerItem(
        Icons.emoji_events_outlined,
        'Leaderboard',
        '/leaderboard',
        const Color(0xFFF59E0B),
      ),
    ]),
    _DrawerSection('Account', [
      _DrawerItem(
        Icons.notifications_outlined,
        'Notifications',
        '/notifications',
        const Color(0xFFF97315),
      ),
      _DrawerItem(
        Icons.settings_outlined,
        'Settings',
        '/settings',
        const Color(0xFF6B7280),
      ),
    ]),
  ];

  // flat item count for stagger
  static final int _totalItems = _sections.fold(
    0,
    (s, sec) => s + sec.items.length,
  );

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 350 + _totalItems * 30),
    );

    final int total = _totalItems;
    _slides = List.generate(total, (i) {
      final start = (i / total) * 0.6;
      final end = start + 0.4;
      return Tween<Offset>(
        begin: const Offset(-0.25, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(
            start.clamp(0.0, 1.0),
            end.clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    _fades = List.generate(total, (i) {
      final start = (i / total) * 0.55;
      final end = start + 0.35;
      return CurvedAnimation(
        parent: _ctrl,
        curve: Interval(
          start.clamp(0.0, 1.0),
          end.clamp(0.0, 1.0),
          curve: Curves.easeOut,
        ),
      );
    });

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop();
    if (_shellRoutes.contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromRight = widget.fromRight;
    return Drawer(
      backgroundColor: DS.background,
      width: 290,
      shape: RoundedRectangleBorder(
        borderRadius: fromRight
            ? const BorderRadius.only(
                topLeft: Radius.circular(DS.radiusXl),
                bottomLeft: Radius.circular(DS.radiusXl),
              )
            : const BorderRadius.only(
                topRight: Radius.circular(DS.radiusXl),
                bottomRight: Radius.circular(DS.radiusXl),
              ),
      ),
      child: Column(
        children: [
          // ── Orange branded header ──
          _DrawerHeader(fromRight: fromRight),

          // ── Scrollable nav sections ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s12,
                DS.s16,
                DS.s24,
              ),
              children: _buildSections(),
            ),
          ),

          // ── Footer ──
          _DrawerFooter(),
        ],
      ),
    );
  }

  List<Widget> _buildSections() {
    final widgets = <Widget>[];
    int itemIndex = 0;

    for (int s = 0; s < _sections.length; s++) {
      final section = _sections[s];

      // Section label
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            top: s == 0 ? 0 : DS.s16,
            bottom: DS.s8,
            left: DS.s4,
          ),
          child: Text(
            section.title.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: DS.textHint,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );

      // Items
      for (final item in section.items) {
        final idx = itemIndex++;
        widgets.add(
          SlideTransition(
            position: _slides[idx],
            child: FadeTransition(
              opacity: _fades[idx],
              child: _DrawerTile(
                item: item,
                onTap: () => _navigate(context, item.route),
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

// ─────────────────────────────────────────────
// DRAWER HEADER
// ─────────────────────────────────────────────
class _DrawerHeader extends StatelessWidget {
  final bool fromRight;
  const _DrawerHeader({this.fromRight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C38), DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: fromRight
            ? const BorderRadius.only(topLeft: Radius.circular(DS.radiusXl))
            : const BorderRadius.only(topRight: Radius.circular(DS.radiusXl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.s20, DS.s20, DS.s16, DS.s24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo pill
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.30),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: DS.s10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BANSAL',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Student Portal',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: DS.s16),

              // Tagline
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: DS.s6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.20),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DS.s6),
                    const Text(
                      'Quick access navigation',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
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

// ─────────────────────────────────────────────
// DRAWER TILE
// ─────────────────────────────────────────────
class _DrawerTile extends StatelessWidget {
  final _DrawerItem item;
  final VoidCallback onTap;
  const _DrawerTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isActive =
        currentRoute == item.route || currentRoute.startsWith('${item.route}/');

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s4),
      child: Material(
        color: isActive ? DS.primaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          splashColor: DS.primary.withOpacity(0.10),
          highlightColor: DS.primary.withOpacity(0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s12,
              vertical: DS.s10,
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isActive
                        ? DS.primary.withOpacity(0.15)
                        : DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: isActive ? DS.primary : DS.textSecondary,
                  ),
                ),

                const SizedBox(width: DS.s12),

                // Label
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive ? DS.primary : DS.textPrimary,
                    ),
                  ),
                ),

                // Active indicator dot OR chevron
                if (isActive)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: DS.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: DS.textHint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DRAWER FOOTER
// ─────────────────────────────────────────────
class _DrawerFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(DS.s20, DS.s12, DS.s20, DS.s20),
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Version badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s8,
                vertical: DS.s4,
              ),
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'v1.0.0',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: DS.primary,
                ),
              ),
            ),
            const SizedBox(width: DS.s8),
            Text(
              'LearnApp · Student Edition',
              style: TextStyle(fontSize: 11.5, color: DS.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
