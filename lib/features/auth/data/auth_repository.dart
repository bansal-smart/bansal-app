import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/providers.dart';


class AuthUser {
  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;
  const AuthUser({required this.id, this.email, this.name, this.avatarUrl});
}

class AuthRepository {
  final Prefs _prefs;
  AuthRepository(this._prefs);

  User? get _user => supabaseOrNull?.auth.currentUser;

  bool get isSignedIn => _user != null || _mockUser != null || _prefs.phoneSignedIn;

  AuthUser? _mockUser; // kept only as fallback when Supabase is unavailable

  /// Step 1 — send 6-digit OTP to the phone via the PRP SMS edge function.
  /// Native Supabase phone auth is not enabled on this project; PRP SMS is
  /// wired in as the `prpsms-send-otp` / `prpsms-verify-otp` edge functions
  /// instead (same ones the web app uses).
  Future<void> sendPhoneOtp({required String phone}) async {
    final sb = supabaseOrNull;
    if (sb == null) return;
    try {
      final res = await sb.functions.invoke(
        'prpsms-send-otp',
        body: {'phone': phone, 'purpose': 'login'},
      );
      if (res.status != 200) {
        final msg = (res.data is Map) ? res.data['error'] as String? : null;
        throw Exception(msg ?? 'Failed to send OTP. Please try again.');
      }
    } on FunctionException catch (e) {
      final msg = (e.details is Map) ? e.details['error'] as String? : null;
      throw Exception(msg ?? 'Failed to send OTP. Please try again.');
    }
  }

  /// Check if a phone number already has a registered profile with completed
  /// onboarding. Uses a SECURITY DEFINER RPC to bypass RLS (user not signed
  /// in yet at this point). Called before OTP so routing is known upfront.
  Future<bool> isPhoneRegistered({required String phone}) async {
    final sb = supabaseOrNull;
    if (sb == null) return false;
    try {
      final result = await sb.rpc('is_phone_registered', params: {'p_phone': phone});
      final registered = result as bool? ?? false;
      debugPrint('[Auth] isPhoneRegistered: phone=$phone → $registered');
      return registered;
    } catch (e) {
      debugPrint('[Auth] isPhoneRegistered error: $e');
      return false;
    }
  }

  /// Step 2 — verify the OTP entered by the user and establish a session.
  /// Calls the `prpsms-verify-otp` edge function, which validates the OTP,
  /// finds-or-creates the auth user for this phone, and mints a magic-link
  /// token; that token is then exchanged here for a real Supabase session.
  /// Returns true if the profile is already set up (returning user).
  Future<bool> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    final sb = supabaseOrNull;
    if (sb == null) return false;
    final e164 = phone.startsWith('+') ? phone : '+91$phone';

    // Sign out any stale session for a different number
    final current = sb.auth.currentUser;
    final currentPhone = current?.phone ?? '';
    if (current != null && currentPhone != e164) {
      await sb.auth.signOut();
    }

    // Clear cached profile BEFORE verifyOTP so that when onAuthStateChange
    // fires the router redirect it always reads profileSetupDone=false,
    // then restoreProfileFromDb sets it back to true for returning users.
    await _prefs.setProfileSetupDone(false);
    await _prefs.setUserName('');
    await _prefs.setUserClass('');
    await _prefs.setUserExam('');

    Map<String, dynamic> result;
    try {
      final res = await sb.functions.invoke(
        'prpsms-verify-otp',
        body: {'phone': phone, 'otp': token, 'purpose': 'login'},
      );
      if (res.status != 200 || res.data is! Map) {
        final msg = (res.data is Map) ? res.data['error'] as String? : null;
        throw Exception(msg ?? 'Incorrect or expired OTP.');
      }
      result = Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final msg = (e.details is Map) ? e.details['error'] as String? : null;
      throw Exception(msg ?? 'Incorrect or expired OTP.');
    }

    final tokenHash = result['token_hash'] as String?;
    final email = result['email'] as String?;
    if (tokenHash == null || email == null) {
      throw Exception('Verification failed. Please try again.');
    }

    await sb.auth.verifyOTP(
      tokenHash: tokenHash,
      type: OtpType.magiclink,
    );

    await _prefs.setPhoneNumber(phone);
    await _prefs.setPhoneSignedIn(true);

    final hasProfile = await restoreProfileFromDb();
    debugPrint('[Auth] verifyPhoneOtp → hasProfile=$hasProfile uid=${sb.auth.currentUser?.id}');
    return hasProfile;
  }

  /// After sign-in, load profile from DB and sync to prefs.
  /// Returns true if profile was found (returning user → skip setup).
  Future<bool> restoreProfileFromDb() async {
    final sb = supabaseOrNull;
    if (sb == null) return false;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('profiles')
          .select('full_name, class_level, target_exam, phone, onboarding_completed')
          .eq('user_id', uid)
          .maybeSingle();
      debugPrint('[Auth] restoreProfileFromDb: uid=$uid row=$row');
      if (row == null) return false;
      final name      = row['full_name'] as String? ?? '';
      final cls       = row['class_level'] as String? ?? '';
      final exam      = row['target_exam'] as String? ?? '';
      debugPrint('[Auth] restoreProfileFromDb: name="$name" cls="$cls"');
      // Students are created by super admin with their data already filled
      // in, so a name on the profile is enough to treat this as a returning
      // user — there is no in-app onboarding wizard to complete.
      if (name.isEmpty) return false;
      await _prefs.setUserName(name);
      await _prefs.setUserClass(cls);
      await _prefs.setUserExam(exam);
      await _prefs.setProfileSetupDone(true);
      return true;
    } catch (e) {
      debugPrint('[Auth] restoreProfileFromDb ERROR: $e');
      return false;
    }
  }

  // Temporarily holds the password chosen on signup form until OTP is verified
  // and updatePassword() is called from ResetPasswordScreen.
  String? pendingPassword;

  AuthUser? currentUser() {
    if (_user != null) {
      // For anonymous phone-auth users, use stored phone as display name
      final metaName = _user!.userMetadata?['full_name'] as String?;
      final displayName = (metaName != null && metaName.isNotEmpty)
          ? metaName
          : (_prefs.phoneNumber.isNotEmpty ? _prefs.phoneNumber : null);
      return AuthUser(
        id: _user!.id,
        email: _user!.email,
        name: displayName,
        avatarUrl: _user!.userMetadata?['avatar_url'] as String?,
      );
    }
    return _mockUser;
  }

  // ── Email + password login (existing accounts) ──────────────────────────
  Future<void> signIn({required String email, required String password}) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithPassword(email: email, password: password);
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: email.split('@').first,
      );
    }
  }

  // ── Email signup — sends OTP for verification ───────────────────────────
  // Stores user metadata and sends a 6-digit OTP via signInWithOtp.
  // After OTP is verified in OtpVerificationScreen, the user is signed in
  // and then redirected to ResetPasswordScreen to set their password.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String region = 'IN',
  }) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {
          'full_name': name,
          'phone': phone ?? '',
          'region': region,
        },
      );
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: name,
      );
    }
  }

  // ── "Continue with Google" — sends 6-digit OTP to Gmail ─────────────────
  Future<void> signInWithGoogle(String email) async {
    final sb = supabaseOrNull;
    if (sb == null) return;
    await sb.auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  // ── Verify 6-digit OTP entered by the user ───────────────────────────────
  Future<void> verifyOtp({
    required String email,
    required String token,
    bool isGoogleFlow = false,
  }) async {
    final sb = supabaseOrNull;
    if (sb == null) return;
    await sb.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  // ── Resend OTP ───────────────────────────────────────────────────────────
  Future<void> resendOtp({
    required String email,
    bool isGoogleFlow = false,
  }) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
    }
  }

  // ── Forgot password — sends 6-digit OTP via recovery email ─────────────
  Future<void> sendPasswordResetOtp(String email) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    }
  }

  // ── Verify recovery OTP ──────────────────────────────────────────────────
  // Uses OtpType.magiclink because sendPasswordResetOtp calls signInWithOtp
  // which generates a magiclink-type token, not a signup-type token.
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final sb = supabaseOrNull;
    if (sb == null) return;
    await sb.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.magiclink,
    );
  }

  // ── Update password after OTP verified ──────────────────────────────────
  Future<void> updatePassword(String newPassword) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.updateUser(UserAttributes(password: newPassword));
    }
  }

  Future<void> signOut() async {
    _mockUser = null;
    await _prefs.setPhoneSignedIn(false);
    await _prefs.setPhoneNumber('');
    await _prefs.setProfileSetupDone(false);
    await supabaseOrNull?.auth.signOut();
  }

  Stream<bool> authChanges() {
    final sb = supabaseOrNull;
    if (sb != null) {
      return sb.auth.onAuthStateChange.map((_) => sb.auth.currentUser != null);
    }
    return const Stream.empty();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final prefs = ref.watch(prefsProvider);
  return AuthRepository(prefs);
});

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, bool>((ref) {
  return AuthStateNotifier(ref.watch(authRepositoryProvider));
});

class AuthStateNotifier extends StateNotifier<bool> {
  final AuthRepository _repo;
  AuthStateNotifier(this._repo) : super(_repo.isSignedIn) {
    _repo.authChanges().listen((v) => state = v);
  }
  void refresh() => state = _repo.isSignedIn;
}
