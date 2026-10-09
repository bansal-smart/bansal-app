import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/supabase/supabase_client.dart';
import '../../core/theme/colors.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/models/user_profile.dart';
import '../auth/data/repositories/user_repository.dart';
import '../enrollments/data/repositories/enrollments_repository.dart';
import '../profile/data/dashboard_stats_providers.dart';
import '../profile/data/profile_providers.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFEAF0FC);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFF5F6FA);
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

// Dropdown option lists — must match lib/features/auth/profile_setup_screen.dart
const _kExams = ['JEE', 'NEET', 'Foundation'];
const _kClasses = ['8th', '9th', '10th', '11th', '12th', 'Dropper'];
const _kStates = [
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

// ─────────────────────────────────────────────
// PROFILE SCREEN (single self-contained screen — bottom-nav "Profile" tab)
// ─────────────────────────────────────────────
class ProfileDashboardScreen extends ConsumerStatefulWidget {
  const ProfileDashboardScreen({super.key});

  @override
  ConsumerState<ProfileDashboardScreen> createState() =>
      _ProfileDashboardScreenState();
}

class _ProfileDashboardScreenState
    extends ConsumerState<ProfileDashboardScreen> {
  // Personal Info form controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _fatherNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String? _classLevel;
  String? _targetExam;
  String? _state;

  bool _profileLoaded = false;
  bool _saving = false;
  bool _saved = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _fatherNameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _populateFromProfile(UserProfile profile) {
    if (_profileLoaded) return;
    _profileLoaded = true;
    _nameCtrl.text = profile.fullName ?? '';
    _phoneCtrl.text = profile.phone ?? '';
    _parentPhoneCtrl.text = profile.parentPhone ?? '';
    _fatherNameCtrl.text = profile.fatherName ?? '';
    _cityCtrl.text = profile.city ?? '';
    _classLevel = profile.classLevel;
    _targetExam = profile.targetExam;
    _state = profile.state;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      _avatarUrl = profile.avatarUrl;
    }
    setState(() {});
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _pickAndUploadAvatar() async {
    final sb = supabaseOrNull;
    final user = ref.read(authRepositoryProvider).currentUser();
    if (sb == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to upload a photo.')),
      );
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final path = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await sb.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final url = sb.storage.from('avatars').getPublicUrl(path);
      await sb.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
      await sb
          .from('profiles')
          .update({'avatar_url': url})
          .eq('user_id', user.id);

      if (!mounted) return;
      setState(() => _avatarUrl = url);
      ref.invalidate(userProfileProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    try {
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null) {
        final updated = profile.copyWith(
          fullName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          parentPhone: _parentPhoneCtrl.text.trim(),
          fatherName: _fatherNameCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          state: _state,
          classLevel: _classLevel,
          targetExam: _targetExam,
        );
        await UserRepository().updateUserProfile(updated);

        final sb = Supabase.instance.client;
        await sb.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': updated.fullName ?? '',
              if (updated.avatarUrl != null) 'avatar_url': updated.avatarUrl,
            },
          ),
        );

        final prefs = ref.read(prefsProvider);
        if (updated.targetExam != null) {
          await prefs.setUserExam(updated.targetExam!);
        }
        if (updated.classLevel != null) {
          await prefs.setUserClass(updated.classLevel!);
        }
        if (updated.targetExam != null && updated.targetExam!.isNotEmpty) {
          await EnrollmentsRepository().autoEnrollFreeCourses(
            exam: updated.targetExam!,
            userClass: updated.classLevel ?? '',
          );
        }

        _profileLoaded = true;
        ref.invalidate(userProfileProvider);
        ref.invalidate(profileSetupInfoProvider);
      }
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _saved = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _logout() async {
    HapticFeedback.mediumImpact();
    final confirmed = await _confirmLogout(context);
    if (!confirmed || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    ref.read(authStateProvider.notifier).refresh();
    if (mounted) context.go('/login');
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will be signed out of your account. You can log back in anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: DS.error, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Lets the Edit Profile sheet rebuild whenever this screen's state changes
  /// (dropdown picks, saving / saved flags).
  StateSetter? _sheetSetState;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sheetSetState?.call(() {});
  }

  Future<void> _openEditProfile() async {
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null) _populateFromProfile(profile);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          _sheetSetState = setSheetState;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 14),
                  _PersonalInfoCard(
                    nameCtrl: _nameCtrl,
                    phoneCtrl: _phoneCtrl,
                    parentPhoneCtrl: _parentPhoneCtrl,
                    fatherNameCtrl: _fatherNameCtrl,
                    cityCtrl: _cityCtrl,
                    classLevel: _classLevel,
                    targetExam: _targetExam,
                    state: _state,
                    saving: _saving,
                    saved: _saved,
                    onClassLevelChanged: (v) => setState(() => _classLevel = v),
                    onTargetExamChanged: (v) => setState(() => _targetExam = v),
                    onStateChanged: (v) => setState(() => _state = v),
                    onSave: _save,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    _sheetSetState = null;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<UserProfile?>>(userProfileProvider, (prev, next) {
      final profile = next.valueOrNull;
      if (profile != null) _populateFromProfile(profile);
    });

    final user = ref.watch(authRepositoryProvider).currentUser();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final setupInfo = ref.watch(profileSetupInfoProvider);
    final prefs = ref.read(prefsProvider);

    final String name = profile?.fullName?.trim().isNotEmpty == true
        ? profile!.fullName!.trim()
        : setupInfo.name.isNotEmpty
        ? setupInfo.name
        : (user?.name ?? 'Learner');
    final String initials = _initials(name);
    final String? avatarUrl =
        _avatarUrl ?? profile?.avatarUrl ?? user?.avatarUrl;
    final String examTag = profile?.targetExam?.isNotEmpty == true
        ? profile!.targetExam!
        : setupInfo.exam.isNotEmpty
        ? setupInfo.exam
        : prefs.goal;
    final String classTag = profile?.classLevel?.isNotEmpty == true
        ? profile!.classLevel!
        : setupInfo.userClass;

    // Login identifier: prefer roll number, then phone, then email.
    final String loginId = (profile?.rollNumber?.isNotEmpty == true)
        ? profile!.rollNumber!
        : (profile?.phone?.isNotEmpty == true)
        ? profile!.phone!
        : (user?.email ?? '—');

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, DS.s32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'My Account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 18),
            _HeroCard(
              name: name,
              initials: initials,
              avatarUrl: avatarUrl,
              uploading: _uploadingAvatar,
              onPickAvatar: _pickAndUploadAvatar,
              onEditProfile: _openEditProfile,
              examTag: examTag,
              classTag: classTag,
              loginId: loginId,
            ),
            const SizedBox(height: 24),
            const _Label('My Stats'),
            const SizedBox(height: 12),
            const _StatsRow(),
            const SizedBox(height: 26),
            const _Label('Performance'),
            const SizedBox(height: 12),
            const _PerformanceCard(),
            const SizedBox(height: 26),
            const _Label('Account'),
            const SizedBox(height: 12),
            _AccountRow(
              icon: LucideIcons.settings,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
            const SizedBox(height: 10),
            _AccountRow(
              icon: LucideIcons.bell,
              label: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
            const SizedBox(height: 10),
            _AccountRow(
              icon: LucideIcons.logOut,
              label: 'Logout',
              destructive: true,
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: DS.textHint,
        borderRadius: BorderRadius.circular(99),
      ),
    ),
  );
}

/// Upper-case section label used across the redesigned tabs.
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: 0.2,
    ),
  );
}

const _cardShadow = [
  BoxShadow(color: Color(0x1F102A5C), blurRadius: 14, offset: Offset(0, 5)),
];

// ─────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String name;
  final String initials;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPickAvatar;
  final VoidCallback onEditProfile;
  final String examTag;
  final String classTag;
  final String loginId;

  const _HeroCard({
    required this.name,
    required this.initials,
    required this.avatarUrl,
    required this.uploading,
    required this.onPickAvatar,
    required this.onEditProfile,
    required this.examTag,
    required this.classTag,
    required this.loginId,
  });

  /// "11th" → "Class 11"; anything else (e.g. "Dropper") is shown as-is.
  static String _classLabel(String raw) {
    final match = RegExp(r'^(\d+)(st|nd|rd|th)?$').firstMatch(raw.trim());
    return match == null ? raw : 'Class ${match.group(1)}';
  }

  static const double _avatar = 104;

  @override
  Widget build(BuildContext context) {
    final initialsText = Text(
      initials,
      style: const TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33102A5C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Semantics(
            label: '$name profile photo',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: _avatar,
                  height: _avatar,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2F5EA8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: uploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : (avatarUrl != null && avatarUrl!.isNotEmpty)
                      ? Image.network(
                          avatarUrl!,
                          width: _avatar,
                          height: _avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => initialsText,
                        )
                      : initialsText,
                ),
                Positioned(
                  bottom: 8,
                  right: -2,
                  child: Tooltip(
                    message: 'Change photo',
                    child: GestureDetector(
                      onTap: onPickAvatar,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x33000000), blurRadius: 4),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.camera,
                          size: 14,
                          color: AppColors.deepNavy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onEditProfile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF3C6DC4),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              if (examTag.isNotEmpty) _Chip(label: examTag.toUpperCase()),
              if (classTag.isNotEmpty) _Chip(label: _classLabel(classTag)),
              if (loginId.isNotEmpty && loginId != '—') _Chip(label: loginId),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 52),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1C42),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  static String _v<T>(AsyncValue<T> async, String Function(T) format) =>
      async.when(data: format, loading: () => '—', error: (_, _) => '—');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final tests = ref.watch(testsCompletedProvider);
    final accuracy = ref.watch(accuracyProvider);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: LucideIcons.flame,
            color: AppColors.orange,
            tint: const Color(0xFFFDEBD9),
            label: 'Day streak',
            value: _v(streak, (v) => '$v'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            icon: LucideIcons.clipboardList,
            color: const Color(0xFF6366F1),
            tint: const Color(0xFFECEBFC),
            label: 'Tests',
            value: _v(tests, (v) => '$v'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _StatTile(
            icon: LucideIcons.target,
            color: DS.success,
            tint: const Color(0xFFDDF5EC),
            label: 'Accuracy',
            value: _v(accuracy, (v) => v == null ? '—' : '$v%'),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color tint;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.tint,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 32,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: DS.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PERFORMANCE (mock-test score trend)
// ─────────────────────────────────────────────
class _PerformanceCard extends ConsumerWidget {
  const _PerformanceCard();

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  void _showReports(BuildContext context, List<TestReportSummary> reports) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            const _SheetHandle(),
            const SizedBox(height: 16),
            const _Label('Test reports'),
            const SizedBox(height: 12),
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _cardShadow,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < reports.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: DS.border),
                    _ReportRow(
                      report: reports[i],
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.push('/test-result/${reports[i].attemptId}');
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(testReportHistoryProvider);
    final reports = history.valueOrNull ?? const <TestReportSummary>[];
    final latest = reports.isEmpty ? null : reports.first;

    // History arrives newest first; the chart reads left → right in time.
    final ratios = reports.reversed
        .map((r) => r.totalMarks > 0 ? (r.score / r.totalMarks) * 100 : 0.0)
        .map((v) => v.clamp(0.0, 100.0).toDouble())
        .toList();
    if (ratios.length == 1) ratios.add(ratios.first);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: _cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mock-test score',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (history.hasError)
                GestureDetector(
                  onTap: () => ref.invalidate(testReportHistoryProvider),
                  child: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 10, color: AppColors.primary),
                  ),
                )
              else
                GestureDetector(
                  onTap: reports.isEmpty
                      ? null
                      : () => _showReports(context, reports),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text(
                        'Full Details',
                        style: TextStyle(
                          fontSize: 10,
                          color: reports.isEmpty
                              ? DS.textHint
                              : DS.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: reports.isEmpty ? DS.textHint : DS.textSecondary,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            latest == null ? '—' : _num(latest.score),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (latest != null && latest.totalMarks > 0)
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Text(
                '/ ${_num(latest.totalMarks)}',
                style: const TextStyle(fontSize: 7, color: AppColors.ink),
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 66,
            child: history.isLoading
                ? const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : ratios.isEmpty
                ? const Center(
                    child: Text(
                      'Complete a test to see your score trend.',
                      style: TextStyle(fontSize: 11, color: DS.textSecondary),
                    ),
                  )
                : _ScoreChart(values: ratios),
          ),
        ],
      ),
    );
  }
}

class _ScoreChart extends StatelessWidget {
  /// Scores as a percentage of max marks, oldest first.
  final List<double> values;
  const _ScoreChart({required this.values});

  @override
  Widget build(BuildContext context) {
    const line = Color(0xFF3B5BA9);
    return Semantics(
      label: 'Mock-test score trend',
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.35,
              preventCurveOverShooting: true,
              color: line,
              barWidth: 1.4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFE6EEFB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final TestReportSummary report;
  final VoidCallback onTap;

  const _ReportRow({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = report.submittedAt;
    final dateLabel = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DS.s14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.tileBlue,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(
                LucideIcons.chartLine,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${report.correct} correct · ${report.wrong} wrong · ${report.unattempted} unattempted${dateLabel.isEmpty ? '' : ' · $dateLabel'}',
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: DS.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DS.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  report.totalMarks > 0
                      ? '${report.score.toStringAsFixed(1)}/${report.totalMarks.toStringAsFixed(0)}'
                      : report.score.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  report.released ? 'View report' : 'Report pending',
                  style: TextStyle(
                    fontSize: 10,
                    color: report.released ? DS.success : DS.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: DS.s4),
            const Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: DS.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalInfoCard extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController parentPhoneCtrl;
  final TextEditingController fatherNameCtrl;
  final TextEditingController cityCtrl;
  final String? classLevel;
  final String? targetExam;
  final String? state;
  final bool saving;
  final bool saved;
  final ValueChanged<String?> onClassLevelChanged;
  final ValueChanged<String?> onTargetExamChanged;
  final ValueChanged<String?> onStateChanged;
  final VoidCallback onSave;

  const _PersonalInfoCard({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.parentPhoneCtrl,
    required this.fatherNameCtrl,
    required this.cityCtrl,
    required this.classLevel,
    required this.targetExam,
    required this.state,
    required this.saving,
    required this.saved,
    required this.onClassLevelChanged,
    required this.onTargetExamChanged,
    required this.onStateChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: 'Personal Info'),
          const SizedBox(height: DS.s16),
          _AppField(
            controller: nameCtrl,
            label: 'Full Name',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: DS.s12),
          _AppField(
            controller: phoneCtrl,
            label: 'Phone',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DS.s12),
          _AppField(
            controller: parentPhoneCtrl,
            label: "Parent's Phone",
            icon: Icons.phone_in_talk_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: DS.s12),
          _AppField(
            controller: fatherNameCtrl,
            label: "Father's Name",
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: DS.s12),
          _DropdownField<String>(
            value: classLevel,
            label: 'Class',
            icon: Icons.class_outlined,
            items: _kClasses,
            labels: _kClasses,
            onChanged: onClassLevelChanged,
          ),
          const SizedBox(height: DS.s12),
          _DropdownField<String>(
            value: targetExam,
            label: 'Stream',
            icon: Icons.emoji_events_outlined,
            items: _kExams,
            labels: _kExams,
            onChanged: onTargetExamChanged,
          ),
          const SizedBox(height: DS.s12),
          _AppField(
            controller: cityCtrl,
            label: 'City',
            icon: Icons.location_city_outlined,
          ),
          const SizedBox(height: DS.s12),
          _DropdownField<String>(
            value: state,
            label: 'State',
            icon: Icons.map_outlined,
            items: _kStates,
            labels: _kStates,
            onChanged: onStateChanged,
          ),
          const SizedBox(height: DS.s20),
          if (saved) ...[_SuccessBanner(), const SizedBox(height: DS.s12)],
          _PrimaryButton(
            label: saved ? 'Saved!' : 'Save Changes',
            loading: saving,
            saved: saved,
            onTap: saving ? null : onSave,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: DS.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: DS.s8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;

  const _AppField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(
        fontSize: 15,
        color: DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DS.textSecondary, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 20, color: DS.textSecondary),
        ),
        filled: true,
        fillColor: DS.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.primary, width: 1.8),
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final IconData icon;
  final List<T> items;
  final List<String> labels;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.value,
    required this.label,
    required this.icon,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: DS.textSecondary,
        size: 20,
      ),
      style: const TextStyle(
        fontSize: 14,
        color: DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      dropdownColor: DS.surface,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: DS.textSecondary, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 18, color: DS.textSecondary),
        ),
        filled: true,
        fillColor: DS.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.border, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.primary, width: 1.8),
        ),
      ),
      items: List.generate(
        items.length,
        (i) => DropdownMenuItem<T>(
          value: items[i],
          child: Text(
            labels[i],
            style: const TextStyle(fontSize: 13.5, color: DS.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      decoration: BoxDecoration(
        color: DS.successSurface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.success.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: DS.success, size: 18),
          SizedBox(width: DS.s8),
          Text(
            'Profile updated successfully!',
            style: TextStyle(
              color: DS.success,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool saved;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.saved = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color startColor = saved ? DS.success : DS.primary;
    final Color endColor = saved ? const Color(0xFF059669) : DS.primaryDark;

    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : LinearGradient(colors: [startColor, endColor]),
          borderRadius: BorderRadius.circular(DS.radiusMd),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: (saved ? DS.success : DS.primary).withOpacity(0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: DS.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (saved) ...[
                      const Icon(Icons.check_circle_rounded, size: 20),
                      const SizedBox(width: DS.s8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
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
// ACCOUNT ROWS
// ─────────────────────────────────────────────
class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  const _AccountRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  static const _danger = Color(0xFFE5484D);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tileBlue,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white, width: 1.2),
            boxShadow: _cardShadow,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: destructive
                    ? Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE2E2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          LucideIcons.logOut,
                          size: 11,
                          color: _danger,
                        ),
                      )
                    : Icon(icon, size: 18, color: AppColors.ink),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: destructive ? _danger : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
