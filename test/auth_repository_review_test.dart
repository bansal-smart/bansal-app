import 'package:bansal/core/storage/preferences.dart';
import 'package:bansal/features/auth/data/auth_repository.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dotenv.testLoad(fileInput: '');
  });

  test('Play review number skips SMS and accepts the fixed OTP', () async {
    final prefs = await Prefs.create();
    final repository = AuthRepository(prefs);

    await repository.sendPhoneOtp(phone: '830260000');
    final hasCompletedProfile = await repository.verifyPhoneOtp(
      phone: '+91830260000',
      token: '123456',
    );

    expect(hasCompletedProfile, isTrue);
    expect(repository.isSignedIn, isTrue);
    expect(repository.currentUser()?.id, 'google-play-review-user');
    expect(prefs.phoneNumber, '+91830260000');
    expect(prefs.phoneSignedIn, isTrue);
    expect(prefs.profileSetupDone, isTrue);
    expect(prefs.userName, 'Demo Student');
    expect(prefs.userClass, '12');
    expect(prefs.userExam, 'IIT-JEE');
  });

  test('Play review number rejects every other OTP', () async {
    final prefs = await Prefs.create();
    final repository = AuthRepository(prefs);

    expect(
      repository.verifyPhoneOtp(phone: '830260000', token: '654321'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('Invalid OTP'),
        ),
      ),
    );
    expect(repository.isSignedIn, isFalse);
  });
}
