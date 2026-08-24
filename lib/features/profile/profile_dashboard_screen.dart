import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/supabase/supabase_client.dart';
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

    return Container(
      color: DS.background,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroCard(
                name: name,
                initials: initials,
                avatarUrl: avatarUrl,
                uploading: _uploadingAvatar,
                onPickAvatar: _pickAndUploadAvatar,
                examTag: examTag,
                classTag: classTag,
                loginId: loginId,
              ),
              const SizedBox(height: DS.s16),
              const _StatsRow(),
              const SizedBox(height: DS.s20),
              _SectionHeader(title: 'Account'),
              const SizedBox(height: DS.s12),
              _AccountCard(
                onSettings: () => context.push('/settings'),
                onNotifications: () => context.push('/notifications'),
                onLogout: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO CARD
// ─────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String name;
  final String initials;
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback onPickAvatar;
  final String examTag;
  final String classTag;
  final String loginId;

  const _HeroCard({
    required this.name,
    required this.initials,
    required this.avatarUrl,
    required this.uploading,
    required this.onPickAvatar,
    required this.examTag,
    required this.classTag,
    required this.loginId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(DS.s20, DS.s24, DS.s20, DS.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DS.primaryDark, DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusXl),
        boxShadow: [
          BoxShadow(
            color: DS.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.45),
                    width: 2.5,
                  ),
                ),
                child: uploading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onPickAvatar,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 15,
                      color: DS.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s12),
          Text(
            name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: DS.s8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: DS.s6,
            children: [
              if (examTag.isNotEmpty) _Chip(label: examTag),
              if (classTag.isNotEmpty) _Chip(label: classTag),
            ],
          ),
          const SizedBox(height: DS.s10),
          Text(
            loginId,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withOpacity(0.80),
              fontWeight: FontWeight.w500,
            ),
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
    padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.20),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final tests = ref.watch(testsCompletedProvider);
    final accuracy = ref.watch(accuracyProvider);
    final percentile = ref.watch(airPercentileProvider);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            color: const Color(0xFFF59E0B),
            label: 'Streak',
            value: streak.when(
              data: (v) => '$v',
              loading: () => '—',
              error: (_, __) => '—',
            ),
          ),
        ),
        const SizedBox(width: DS.s8),
        Expanded(
          child: _StatTile(
            icon: Icons.assignment_turned_in_rounded,
            color: const Color(0xFF6366F1),
            label: 'Tests',
            value: tests.when(
              data: (v) => '$v',
              loading: () => '—',
              error: (_, __) => '—',
            ),
          ),
        ),
        const SizedBox(width: DS.s8),
        Expanded(
          child: _StatTile(
            icon: Icons.track_changes_rounded,
            color: DS.success,
            label: 'Accuracy',
            value: accuracy.when(
              data: (v) => v == null ? '—' : '$v%',
              loading: () => '—',
              error: (_, __) => '—',
            ),
          ),
        ),
        const SizedBox(width: DS.s8),
        Expanded(
          child: _StatTile(
            icon: Icons.leaderboard_rounded,
            color: const Color(0xFF06B6D4),
            label: 'Percentile',
            value: percentile.when(
              data: (v) => v == null ? '—' : v.toStringAsFixed(1),
              loading: () => '—',
              error: (_, __) => '—',
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: DS.s12, horizontal: DS.s8),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: DS.s6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: DS.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PERSONAL INFO CARD
// ─────────────────────────────────────────────
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
// ACCOUNT CARD
// ─────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final VoidCallback onSettings, onNotifications, onLogout;
  const _AccountCard({
    required this.onSettings,
    required this.onNotifications,
    required this.onLogout,
  });

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
      child: Column(
        children: [
          _AccountTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            color: DS.textSecondary,
            onTap: onSettings,
            showDivider: true,
          ),
          _AccountTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            color: DS.textSecondary,
            onTap: onNotifications,
            showDivider: true,
          ),
          _AccountTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: DS.error,
            onTap: onLogout,
            showDivider: false,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showDivider;
  final bool isDestructive;

  const _AccountTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.showDivider,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s16,
              vertical: DS.s14,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDestructive ? DS.errorSurface : DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? DS.error : DS.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive
                      ? DS.error.withOpacity(0.5)
                      : DS.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: DS.border,
            indent: DS.s16,
            endIndent: DS.s16,
          ),
      ],
    );
  }
}
