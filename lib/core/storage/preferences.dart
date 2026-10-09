import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _kOnboardingDone = 'onboarding_done';
  static const _kRegion = 'bansal-country';
  static const _kGoal = 'bansal-goal';
  static const _kProfileDone = 'profile_setup_done';
  static const _kUserName = 'user_name';
  static const _kUserClass = 'user_class';
  static const _kUserExam = 'user_exam';
  static const _kPhoneSignedIn = 'phone_signed_in';
  static const _kPhoneNumber = 'phone_number';

  final SharedPreferences _p;
  Prefs(this._p);

  static Future<Prefs> create() async =>
      Prefs(await SharedPreferences.getInstance());

  bool get onboardingDone => _p.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _p.setBool(_kOnboardingDone, v);

  bool get profileSetupDone => _p.getBool(_kProfileDone) ?? false;
  Future<void> setProfileSetupDone(bool v) => _p.setBool(_kProfileDone, v);

  String get userName => _p.getString(_kUserName) ?? '';
  Future<void> setUserName(String v) => _p.setString(_kUserName, v);

  String get userClass => _p.getString(_kUserClass) ?? '';
  Future<void> setUserClass(String v) => _p.setString(_kUserClass, v);

  String get userExam => _p.getString(_kUserExam) ?? '';
  Future<void> setUserExam(String v) => _p.setString(_kUserExam, v);

  bool get phoneSignedIn => _p.getBool(_kPhoneSignedIn) ?? false;
  Future<void> setPhoneSignedIn(bool v) => _p.setBool(_kPhoneSignedIn, v);

  String get phoneNumber => _p.getString(_kPhoneNumber) ?? '';
  Future<void> setPhoneNumber(String v) => _p.setString(_kPhoneNumber, v);

  String get region => _p.getString(_kRegion) ?? 'IN';
  Future<void> setRegion(String v) => _p.setString(_kRegion, v);

  String get goal => _p.getString(_kGoal) ?? 'JEE';
  Future<void> setGoal(String v) => _p.setString(_kGoal, v);
}
