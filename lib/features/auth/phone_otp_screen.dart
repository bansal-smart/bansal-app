import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import 'data/auth_repository.dart';

abstract class _C {
  static const primary = Color(0xFF193F8F);
  static const surface = Color(0xFFF9FAFB);
  static const border = Color(0xFFE5E7EB);
  static const primaryLight = Color(0xFFE8EDF9);
  static const textPrimary = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
  static const error = Color(0xFFEF4444);
}

const _kOtpLength = 6;

class PhoneOtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const PhoneOtpScreen({super.key, required this.phone});

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final _controllers = List.generate(
    _kOtpLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_kOtpLength, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == _kOtpLength;

  void _onDigitChanged(int index, String value) {
    if (value.isEmpty) {
      if (index > 0) _focusNodes[index - 1].requestFocus();
      return;
    }
    final digit = value[value.length - 1];
    _controllers[index].text = digit;
    _controllers[index].selection = TextSelection.fromPosition(
      const TextPosition(offset: 1),
    );
    if (index < _kOtpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      if (_isComplete) _verify();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    if (!_isComplete) {
      setState(() => _error = 'Please enter the complete 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    // Block the router redirect while we verify so onAuthStateChange cannot
    // fire a premature navigation before restoreProfileFromDb completes.
    ref.read(verifyingOtpProvider.notifier).state = true;
    try {
      final repo = ref.read(authRepositoryProvider);
      final hasCompletedProfile = await repo.verifyPhoneOtp(
        phone: widget.phone,
        token: _otp,
      );
      if (!mounted) return;
      ref.read(authStateProvider.notifier).refresh();
      ref.read(needsProfileSetupProvider.notifier).state = !hasCompletedProfile;
      context.go(hasCompletedProfile ? '/home' : '/profile-setup');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final friendly = msg.contains('invalid otp')
          ? 'Invalid OTP'
          : msg.contains('invalid') ||
                msg.contains('incorrect') ||
                msg.contains('expired')
          ? 'Incorrect or expired OTP. Please try again.'
          : 'Verification failed. Please try again.';
      setState(() {
        _loading = false;
        _error = friendly;
      });
      for (final c in _controllers) {
        c.clear();
      }
      if (mounted) _focusNodes[0].requestFocus();
    } finally {
      if (mounted) ref.read(verifyingOtpProvider.notifier).state = false;
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
    try {
      await ref.read(authRepositoryProvider).sendPhoneOtp(phone: widget.phone);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to resend OTP. Try again.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maskedPhone = widget.phone.length >= 10
        ? '+91 ${widget.phone.substring(0, 5)}XXXXX'
        : '+91 ${widget.phone}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Back button ──────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 0, 0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: _C.textPrimary,
                    ),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),

              // ── Illustration ─────────────────────────────────────────
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 0),
                  child: Image.asset(
                    'assets/images/otp.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────
              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verify Your Number',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: _C.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: _C.textSub,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                              text: "We've sent a 6-digit OTP to ",
                            ),
                            TextSpan(
                              text: maskedPhone,
                              style: const TextStyle(
                                color: _C.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // OTP boxes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          _kOtpLength,
                          (i) => _OtpBox(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            hasValue: _controllers[i].text.isNotEmpty,
                            hasError: _error != null,
                            onChanged: (v) => _onDigitChanged(i, v),
                          ),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: _C.error,
                            fontSize: 12.5,
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_loading || !_isComplete)
                              ? null
                              : _verify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _C.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFE5E7EB),
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
                              : const Text(
                                  'Verify & Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Resend
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Didn't receive OTP?  ",
                              style: TextStyle(
                                fontSize: 13.5,
                                color: _C.textSub,
                              ),
                            ),
                            GestureDetector(
                              onTap: _resending ? null : _resend,
                              child: _resending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _C.primary,
                                      ),
                                    )
                                  : const Text(
                                      'Resend OTP',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: _C.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Security note
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: _C.textSub,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'YOUR NUMBER IS SECURE',
                              style: TextStyle(
                                fontSize: 11,
                                color: _C.textSub,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

// ── OTP digit box ──────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasValue;
  final bool hasError;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasValue,
    required this.hasError,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 54,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: onChanged,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: _C.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasValue ? _C.primaryLight : _C.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _C.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: hasError
                  ? _C.error
                  : hasValue
                  ? _C.primary
                  : _C.border,
              width: hasValue ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _C.primary, width: 2.5),
          ),
        ),
      ),
    );
  }
}
