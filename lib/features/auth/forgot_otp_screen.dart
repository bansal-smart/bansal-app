import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import 'data/auth_repository.dart';
import '../../core/providers.dart';

abstract class _DS {
  static const primary = Color(0xFF193F8F);
  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);

  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusXl = 28;
}

class ForgotOtpScreen extends ConsumerStatefulWidget {
  final String email;
  const ForgotOtpScreen({super.key, required this.email});

  @override
  ConsumerState<ForgotOtpScreen> createState() => _ForgotOtpScreenState();
}

class _ForgotOtpScreenState extends ConsumerState<ForgotOtpScreen>
    with SingleTickerProviderStateMixin {
  static const _otpLength = 6;

  final _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _successMsg;

  late AnimationController _ctrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _heroFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _cardFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    _ctrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _isComplete => _otp.length == _otpLength;

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
    if (index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
      if (_isComplete) _verify();
    }
    setState(() {});
  }

  Future<void> _verify() async {
    final otp = _otp;
    if (otp.length < _otpLength) {
      setState(() => _error = 'Please enter the full 6-digit code');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _successMsg = null;
    });
    // Set flag BEFORE the async call so the router redirect is already
    // blocked when Supabase fires the auth-state-change event.
    ref.read(passwordResetInProgressProvider.notifier).state = true;
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyRecoveryOtp(email: widget.email, token: otp);
      if (!mounted) return;
      context.go('/reset-password');
    } catch (e) {
      ref.read(passwordResetInProgressProvider.notifier).state = false;
      final msg = AppException.from(e).userMessage;
      setState(() {
        _error = msg.contains('Invalid') || msg.contains('expired')
            ? 'Invalid OTP. Please check the code and try again.'
            : msg;
      });
      for (final c in _controllers) {
        c.clear();
      }
      if (mounted) _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _successMsg = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOtp(widget.email);
      if (!mounted) return;
      setState(() => _successMsg = 'A new code has been sent to your email.');
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      setState(() => _error = AppException.from(e).userMessage);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.primary,
      body: Stack(
        children: [
          const _HeroDecorations(),
          Column(
            children: [
              Expanded(
                flex: 35,
                child: SafeArea(
                  bottom: false,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: _HeroSection(email: widget.email),
                  ),
                ),
              ),
              Expanded(
                flex: 65,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: _OtpCard(
                      controllers: _controllers,
                      focusNodes: _focusNodes,
                      loading: _loading,
                      resending: _resending,
                      error: _error,
                      successMsg: _successMsg,
                      isComplete: _isComplete,
                      onDigitChanged: _onDigitChanged,
                      onVerify: _loading ? null : _verify,
                      onResend: _resending ? null : _resend,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroDecorations extends StatelessWidget {
  const _HeroDecorations();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -50,
          child: _Circle(size: 220, opacity: 0.10),
        ),
        Positioned(
          top: 50,
          left: -40,
          child: _Circle(size: 130, opacity: 0.07),
        ),
        Positioned(top: 20, right: 60, child: _Circle(size: 55, opacity: 0.12)),
        Positioned(
          top: 120,
          right: -20,
          child: Transform.rotate(
            angle: math.pi / 6,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _HeroSection extends StatelessWidget {
  final String email;
  const _HeroSection({required this.email});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _DS.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: _DS.s20),
          const Text(
            'Check Your Email',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _DS.s8),
          Text(
            'We sent a 6-digit code to',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.80),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OtpCard extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool loading;
  final bool resending;
  final String? error;
  final String? successMsg;
  final bool isComplete;
  final void Function(int, String) onDigitChanged;
  final VoidCallback? onVerify;
  final VoidCallback? onResend;

  const _OtpCard({
    required this.controllers,
    required this.focusNodes,
    required this.loading,
    required this.resending,
    required this.error,
    required this.successMsg,
    required this.isComplete,
    required this.onDigitChanged,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _DS.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(_DS.radiusXl),
          topRight: Radius.circular(_DS.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(_DS.s24, _DS.s32, _DS.s24, _DS.s32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _DS.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: _DS.s12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter OTP',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _DS.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Check your inbox and spam folder',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _DS.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: _DS.s32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                controllers.length,
                (i) => _OtpBox(
                  controller: controllers[i],
                  focusNode: focusNodes[i],
                  hasValue: controllers[i].text.isNotEmpty,
                  onChanged: (v) => onDigitChanged(i, v),
                ),
              ),
            ),

            const SizedBox(height: _DS.s24),

            if (error != null) ...[
              _StatusBanner(message: error!, isError: true),
              const SizedBox(height: _DS.s16),
            ],
            if (successMsg != null) ...[
              _StatusBanner(message: successMsg!, isError: false),
              const SizedBox(height: _DS.s16),
            ],

            // Verify button
            SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: (isComplete && !loading)
                      ? const LinearGradient(
                          colors: [Color(0xFF2B5BB8), _DS.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(_DS.radiusMd),
                  boxShadow: (isComplete && !loading)
                      ? [
                          BoxShadow(
                            color: _DS.primary.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: onVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _DS.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_DS.radiusMd),
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
                      : const Text(
                          'Verify Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: _DS.s24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Didn't receive a code? ",
                  style: TextStyle(color: _DS.textSecondary, fontSize: 14),
                ),
                GestureDetector(
                  onTap: onResend,
                  child: resending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _DS.primary,
                          ),
                        )
                      : const Text(
                          'Resend',
                          style: TextStyle(
                            color: _DS.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasValue;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
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
          color: _DS.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: hasValue ? const Color(0xFFE8EDF9) : _DS.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_DS.radiusMd),
            borderSide: const BorderSide(color: _DS.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_DS.radiusMd),
            borderSide: BorderSide(
              color: hasValue ? _DS.primary : _DS.border,
              width: hasValue ? 2 : 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_DS.radiusMd),
            borderSide: const BorderSide(color: _DS.primary, width: 2.5),
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _DS.s16,
        vertical: _DS.s12,
      ),
      decoration: BoxDecoration(
        color: isError ? _DS.errorSurface : _DS.successSurface,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(
          color: (isError ? _DS.error : _DS.success).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? _DS.error : _DS.success,
            size: 18,
          ),
          const SizedBox(width: _DS.s8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? _DS.error : _DS.success,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
