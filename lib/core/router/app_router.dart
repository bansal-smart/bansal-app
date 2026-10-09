import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/otp_verification_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/forgot_otp_screen.dart';
import '../../features/auth/reset_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/signup_screen.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/courses/course_home_screen.dart';
import '../../features/courses/courses_list_screen.dart';
import '../../features/store/store_screen.dart';
import '../../features/courses/topic_list_screen.dart';
import '../../features/courses/topic_content_screen.dart';
import '../../features/courses/lecture_player_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/home/home_screen.dart';
import '../../features/live/live_list_screen.dart';
import '../../features/live/live_room_screen.dart';
import '../../features/profile/notifications_inbox_screen.dart';
import '../../features/profile/profile_dashboard_screen.dart';
import '../../features/profile/settings_screen.dart';
import '../../features/profile/privacy_policy_screen.dart';
import '../../features/profile/terms_of_service_screen.dart';
import '../../features/auth/phone_otp_screen.dart';
import '../../features/auth/profile_setup_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/tests/test_engine_screen.dart';
import '../../features/tests/test_instructions_screen.dart';
import '../../features/tests/test_response_sheet_screen.dart';
import '../../features/tests/test_result_screen.dart';
import '../../features/tests/tests_list_screen.dart';
import '../providers.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Do NOT watch any frequently-changing providers here — watching causes the
  // entire GoRouter to be recreated (resetting navigation to /splash).
  // All state is read inside the redirect callback instead.
  final auth = ref.read(authRepositoryProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (ctx, state) {
      final loc = state.matchedLocation;
      if (loc == '/splash') return null;
      // Read all state inside the callback — never watch in the provider body
      final resetInProgress = ref.read(passwordResetInProgressProvider);
      if (resetInProgress) return null;
      // Block all redirects while OTP verification + DB profile check is running.
      final verifyingOtp = ref.read(verifyingOtpProvider);
      if (verifyingOtp) return null;
      final signedIn = auth.isSignedIn || ref.read(authStateProvider);
      final prefs = ref.read(prefsProvider);
      final needsProfileSetup =
          ref.read(needsProfileSetupProvider) ||
          (prefs.phoneSignedIn && !prefs.profileSetupDone);
      final atAuth =
          loc == '/login' || loc == '/signup' || loc == '/verify-otp';
      final atPasswordReset =
          loc == '/forgot' || loc == '/forgot-otp' || loc == '/reset-password';
      if (loc == '/onboarding') return null;
      if (loc == '/phone-otp') return null;
      debugPrint('[Router] loc=$loc signedIn=$signedIn');
      if (loc == '/profile-setup') {
        // A newly verified phone has no session until profile setup creates
        // the account, so allow it through while registration is pending.
        if (!signedIn) return auth.hasPendingRegistration ? null : '/login';
        return needsProfileSetup ? null : '/home';
      }
      if (!signedIn && !atAuth && !atPasswordReset) return '/login';
      if (signedIn && needsProfileSetup) return '/profile-setup';
      if (signedIn && atAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/phone-otp',
        parentNavigatorKey: _rootKey,
        builder: (ctx, s) =>
            PhoneOtpScreen(phone: s.uri.queryParameters['phone'] ?? ''),
      ),
      GoRoute(
        path: '/profile-setup',
        parentNavigatorKey: _rootKey,
        builder: (ctx, s) => const ProfileSetupScreen(),
      ),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/forgot',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/forgot-otp',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            ForgotOtpScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/reset-password',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => ResetPasswordScreen(
          source: state.uri.queryParameters['source'] ?? 'forgot',
        ),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (_, state) => OtpVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
          isGoogleFlow: state.uri.queryParameters['source'] == 'google',
        ),
      ),
      ShellRoute(
        navigatorKey: _shellKey,
        builder: (ctx, state, child) =>
            HomeShell(location: state.matchedLocation, child: child),
        routes: [
          // Tabs swap without a transition: they share the shell's background.
          GoRoute(
            path: '/home',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/courses',
            pageBuilder: (_, s) => NoTransitionPage(
              key: s.pageKey,
              child: const CoursesListScreen(),
            ),
          ),
          GoRoute(
            path: '/live',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const LiveListScreen()),
          ),
          GoRoute(
            path: '/tests',
            pageBuilder: (_, s) => NoTransitionPage(
              key: s.pageKey,
              child: const TestsListScreen(),
            ),
          ),
          GoRoute(
            path: '/store',
            pageBuilder: (_, s) =>
                NoTransitionPage(key: s.pageKey, child: const StoreScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, s) => NoTransitionPage(
              key: s.pageKey,
              child: const ProfileDashboardScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/course/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            CourseDetailScreen(courseId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/my-courses/:courseId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            CourseHomeScreen(courseId: s.pathParameters['courseId']!),
      ),
      GoRoute(
        path: '/my-courses/:courseId/subject/:subjectId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TopicListScreen(
          courseId: s.pathParameters['courseId']!,
          subjectId: s.pathParameters['subjectId']!,
          subjectName: s.extra as String? ?? 'Subject',
        ),
      ),
      GoRoute(
        path: '/my-courses/:courseId/subject/:subjectId/topic/:topicId',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TopicContentScreen(
          courseId: s.pathParameters['courseId']!,
          subjectId: s.pathParameters['subjectId']!,
          topicId: s.pathParameters['topicId']!,
          topicName: s.extra as String? ?? 'Topic',
        ),
      ),

      GoRoute(
        path: '/lecture/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            LecturePlayerScreen(lectureId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/live/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => LiveRoomScreen(classId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test-instructions/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            TestInstructionsScreen(testId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TestEngineScreen(testId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test-result/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => TestResultScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/test-response-sheet/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            TestResponseSheetScreen(attemptId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/terms-of-service',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const TermsOfServiceScreen(),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const NotificationsInboxScreen(),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(needsProfileSetupProvider, (_, _) => notifyListeners());
  }
}
