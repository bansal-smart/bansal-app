import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage/preferences.dart';

final prefsProvider = Provider<Prefs>(
  (ref) => throw UnimplementedError('override in main'),
);

/// Exposes the name/class/exam saved during profile setup (phone-auth flow).
/// Returns empty strings when not yet set.
/// Screens that need the DB-authoritative exam should also watch
/// userProfileProvider and prefer its targetExam/classLevel values.
class ProfileSetupInfo {
  final String name;
  final String userClass;
  final String exam;
  const ProfileSetupInfo({
    required this.name,
    required this.userClass,
    required this.exam,
  });
}

final profileSetupInfoProvider = Provider<ProfileSetupInfo>((ref) {
  final prefs = ref.watch(prefsProvider);
  return ProfileSetupInfo(
    name: prefs.userName,
    userClass: prefs.userClass,
    exam: prefs.userExam,
  );
});

class RegionNotifier extends StateNotifier<String> {
  final Prefs _prefs;
  RegionNotifier(this._prefs) : super(_prefs.region);
  Future<void> set(String v) async {
    await _prefs.setRegion(v);
    state = v;
  }
}

final regionProvider = StateNotifierProvider<RegionNotifier, String>(
  (ref) => RegionNotifier(ref.watch(prefsProvider)),
);

// True while the forgot-password OTP→reset flow is active.
// Prevents auth-state change (from verifyOTP) redirecting to /home.
final passwordResetInProgressProvider = StateProvider<bool>((ref) => false);

// Set to true immediately after phone OTP is verified for a NEW user.
// The router reads this to decide whether to send the user to /profile-setup
// instead of /home. Cleared once the user reaches /profile-setup.
final needsProfileSetupProvider = StateProvider<bool>((ref) => false);

// True while verifyPhoneOtp is in progress. Blocks the router redirect so
// restoreProfileFromDb can finish writing profileSetupDone before routing.
final verifyingOtpProvider = StateProvider<bool>((ref) => false);
