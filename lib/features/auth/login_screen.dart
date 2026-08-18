import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/auth_repository.dart';

abstract class DS {
  static const primary     = Color(0xFF193F8F);
  static const bg          = Color(0xFFFFFFFF);
  static const surface     = Color(0xFFF9FAFB);
  static const border      = Color(0xFFE5E7EB);
  static const textPrimary = Color(0xFF111827);
  static const textSub     = Color(0xFF6B7280);
  static const error       = Color(0xFFEF4444);
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(authRepositoryProvider);
      // Check registration status BEFORE sending OTP so the OTP screen
      // knows upfront whether to route to home or profile-setup.
      final isRegistered = await repo.isPhoneRegistered(phone: phone);
      await repo.sendPhoneOtp(phone: phone);
      if (!mounted) return;
      context.push(
        '/phone-otp?phone=${Uri.encodeComponent(phone)}&registered=${isRegistered ? '1' : '0'}',
      );
    } catch (e) {
      final raw = e.toString().replaceFirst('Exception: ', '');
      final friendly = raw.isNotEmpty && raw != 'null'
          ? raw
          : 'Could not send OTP. Check your number and try again.';
      if (mounted) setState(() => _error = friendly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final screenH = mq.size.height - mq.padding.top - mq.padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DS.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Illustration ─────────────────────────────────────────
              SizedBox(
                height: screenH * 0.32,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
                  child: Image.asset(
                    'assets/images/login.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── Form ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                            24, 16, 24, mq.viewInsets.bottom + 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome to Bansal',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: DS.textPrimary,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Start your learning journey and unlock\nyour potential.',
                              style: TextStyle(
                                fontSize: 14,
                                color: DS.textSub,
                                height: 1.5,
                              ),
                            ),

                            const SizedBox(height: 28),

                            const Text(
                              'Phone Number',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: DS.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              decoration: BoxDecoration(
                                color: DS.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _error != null ? DS.error : DS.border,
                                  width: 1.3,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                            color: DS.border, width: 1.3),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Text('📞',
                                            style: TextStyle(fontSize: 16)),
                                        SizedBox(width: 6),
                                        Text(
                                          '+91',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: DS.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneCtrl,
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) {
                                        if (_error != null) {
                                          setState(() => _error = null);
                                        }
                                      },
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: DS.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter your mobile number',
                                        hintStyle: TextStyle(
                                          color: Color(0xFFD1D5DB),
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 14),
                                        counterText: '',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (_error != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _error!,
                                style: const TextStyle(
                                    color: DS.error, fontSize: 12.5),
                              ),
                            ],

                            const SizedBox(height: 24),

                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DS.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Get Started',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 20),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Terms pinned to bottom ────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            const Text(
                              'By continuing, you agree to our ',
                              style:
                                  TextStyle(fontSize: 12, color: DS.textSub),
                            ),
                            GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse('https://www.arke.pro/terms'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: const Text(
                                'Terms of Service',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DS.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: DS.primary,
                                ),
                              ),
                            ),
                            const Text(
                              ' and ',
                              style: TextStyle(
                                  fontSize: 12, color: DS.textSub),
                            ),
                            GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse('https://www.arke.pro/privacy'),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: const Text(
                                'Privacy Policy',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DS.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: DS.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
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
