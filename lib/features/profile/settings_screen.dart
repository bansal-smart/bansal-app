import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/data/auth_repository.dart';

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

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const indigo = Color(0xFF6366F1);
  static const teal = Color(0xFF14B8A6);

  static const double s2 = 2;
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
  static const double s48 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.1, 0.8, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => _LogoutDialog(),
        ) ??
        false;
    if (!ok || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    ref.read(authStateProvider.notifier).refresh();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Orange hero header ──
            _SettingsHeader(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
            ),

            // ── Scrollable settings body ──
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s16,
                      DS.s20,
                      DS.s16,
                      DS.s32,
                    ),
                    children: [
                      // ── Privacy & Legal ──
                      _SectionLabel(
                        label: 'Privacy & Legal',
                        icon: Icons.shield_outlined,
                        color: DS.indigo,
                      ),
                      const SizedBox(height: DS.s10),
                      _SettingsCard(
                        children: [
                          _SettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            color: DS.indigo,
                            label: 'Privacy Policy',
                            onTap: () => context.push('/privacy-policy'),
                          ),
                          _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.description_outlined,
                            color: DS.textSecondary,
                            label: 'Terms of Service',
                            onTap: () => context.push('/terms-of-service'),
                          ),
                          _SettingsDivider(),
                          _SettingsTile(
                            icon: Icons.info_outline_rounded,
                            color: DS.textSecondary,
                            label: 'About the App',
                            subtitle: 'Version 1.0.0',
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: DS.s28),

                      // ── Logout button ──
                      _LogoutButton(onTap: _logout),

                      const SizedBox(height: DS.s20),

                      // ── App version footer ──
                      const _AppVersionFooter(),
                    ],
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

// ─────────────────────────────────────────────
// SETTINGS HEADER
// ─────────────────────────────────────────────
class _SettingsHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _SettingsHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2B5BB8), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(DS.radiusXl),
              bottomRight: Radius.circular(DS.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x47F97315),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s16, DS.s24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Manage your account & preferences',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -50,
          right: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 15,
          right: 20,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SECTION LABEL
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _SectionLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Icon(icon, size: 13, color: color),
        ),
        const SizedBox(width: DS.s8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS CARD (groups tiles)
// ─────────────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ─────────────────────────────────────────────
// SETTINGS TILE (nav)
// ─────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(DS.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s14,
        ),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: DS.s12),

            // Label + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DS.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: DS.s2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: DS.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: DS.textHint,
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────
// SETTINGS DIVIDER
// ─────────────────────────────────────────────
class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    color: DS.border,
    indent: DS.s16 + 38 + DS.s12,
    endIndent: 0,
    thickness: 1,
  );
}

// ─────────────────────────────────────────────
// LOGOUT BUTTON
// ─────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: DS.s14),
        decoration: BoxDecoration(
          color: DS.errorSurface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.error.withOpacity(0.30), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: DS.error, size: 18),
            SizedBox(width: DS.s10),
            Text(
              'Log Out',
              style: TextStyle(
                color: DS.error,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// APP VERSION FOOTER
// ─────────────────────────────────────────────
class _AppVersionFooter extends StatelessWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2B5BB8), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(DS.radiusMd),
            boxShadow: [
              BoxShadow(
                color: DS.primary.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.school_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(height: DS.s10),
        const Text(
          'LearnApp',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: DS.s4),
        const Text(
          'Version 1.0.0 · Student Edition',
          style: TextStyle(fontSize: 12, color: DS.textSecondary),
        ),
        const SizedBox(height: DS.s6),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s10,
            vertical: DS.s4,
          ),
          decoration: BoxDecoration(
            color: DS.primaryLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'Made with 🧡 by Jeevijay Technologies',
            style: TextStyle(
              color: DS.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// LOGOUT CONFIRMATION DIALOG
// ─────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: DS.error,
                size: 28,
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Log Out?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'You will be signed out of your account. You can log back in anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DS.textPrimary,
                      side: const BorderSide(color: DS.border, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: DS.s12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DS.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: DS.s12),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontWeight: FontWeight.w700),
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
}

