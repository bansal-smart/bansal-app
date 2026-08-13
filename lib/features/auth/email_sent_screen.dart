import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import 'data/auth_repository.dart';

abstract class _DS {
  static const primary = Color(0xFFF97315);
  static const primaryLight = Color(0xFFFFF0E6);
  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const double s4 = 4;
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

class EmailSentScreen extends ConsumerStatefulWidget {
  final String email;
  const EmailSentScreen({super.key, required this.email});

  @override
  ConsumerState<EmailSentScreen> createState() => _EmailSentScreenState();
}

class _EmailSentScreenState extends ConsumerState<EmailSentScreen>
    with SingleTickerProviderStateMixin {
  bool _resending = false;
  String? _resendMsg;
  String? _resendError;

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
        .animate(CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    _cardFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _resendMsg = null; _resendError = null; });
    try {
      await ref.read(authRepositoryProvider).resendOtp(email: widget.email);
      if (!mounted) return;
      setState(() => _resendMsg = 'A new link has been sent to your email.');
    } catch (e) {
      setState(() => _resendError = AppException.from(e).userMessage);
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
                flex: 38,
                child: SafeArea(
                  bottom: false,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: const _HeroSection(),
                  ),
                ),
              ),
              Expanded(
                flex: 62,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: _Card(
                      email: widget.email,
                      resending: _resending,
                      resendMsg: _resendMsg,
                      resendError: _resendError,
                      onResend: _resending ? null : _resend,
                      onBackToLogin: () => context.go('/login'),
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

// ── Decorations ─────────────────────────────────────────────────────────────
class _HeroDecorations extends StatelessWidget {
  const _HeroDecorations();
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(top: -70, right: -50, child: _Circle(size: 220, opacity: 0.10)),
      Positioned(top: 60, left: -40, child: _Circle(size: 140, opacity: 0.07)),
      Positioned(top: 20, right: 60, child: _Circle(size: 60, opacity: 0.12)),
      Positioned(
        top: 140, right: -20,
        child: Transform.rotate(
          angle: math.pi / 6,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

// ── Hero ─────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _DS.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76, height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: _DS.s20),
          const Text(
            'Check Your Email',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: -0.5, height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _DS.s8),
          Text(
            'We sent a sign-in link to your inbox',
            style: TextStyle(
                fontSize: 14.5,
                color: Colors.white.withValues(alpha: 0.80),
                height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final String email;
  final bool resending;
  final String? resendMsg;
  final String? resendError;
  final VoidCallback? onResend;
  final VoidCallback onBackToLogin;

  const _Card({
    required this.email,
    required this.resending,
    required this.resendMsg,
    required this.resendError,
    required this.onResend,
    required this.onBackToLogin,
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
            // ── Header ──
            Row(children: [
              Container(
                width: 4, height: 28,
                decoration: BoxDecoration(
                  color: _DS.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: _DS.s12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email on its way!',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: _DS.textPrimary, letterSpacing: -0.3)),
                  Text('Follow the link inside to sign in',
                      style: TextStyle(fontSize: 12.5, color: _DS.textSecondary)),
                ],
              ),
            ]),

            const SizedBox(height: _DS.s24),

            // ── Email address pill ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: _DS.s16, vertical: _DS.s12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E6),
                borderRadius: BorderRadius.circular(_DS.radiusMd),
                border: Border.all(
                    color: _DS.primary.withValues(alpha: 0.25), width: 1.2),
              ),
              child: Row(children: [
                const Icon(Icons.mail_outline_rounded,
                    color: _DS.primary, size: 18),
                const SizedBox(width: _DS.s8),
                Expanded(
                  child: Text(email,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _DS.primary),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),

            const SizedBox(height: _DS.s20),

            // ── Instructions ──
            _Instruction(
              number: '1',
              text: 'Open your Gmail app or inbox',
            ),
            const SizedBox(height: _DS.s12),
            _Instruction(
              number: '2',
              text: 'Find the email from Bansal Scholars',
            ),
            const SizedBox(height: _DS.s12),
            _Instruction(
              number: '3',
              text: 'Tap the "Sign in" link — the app will open automatically',
            ),

            const SizedBox(height: _DS.s24),

            // ── Resend feedback ──
            if (resendMsg != null) ...[
              _Banner(message: resendMsg!, isError: false),
              const SizedBox(height: _DS.s16),
            ],
            if (resendError != null) ...[
              _Banner(message: resendError!, isError: true),
              const SizedBox(height: _DS.s16),
            ],

            // ── Resend button ──
            OutlinedButton(
              onPressed: onResend,
              style: OutlinedButton.styleFrom(
                foregroundColor: _DS.primary,
                side: const BorderSide(color: _DS.primary, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_DS.radiusMd)),
                minimumSize: const Size.fromHeight(50),
              ),
              child: resending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _DS.primary))
                  : const Text('Resend Email',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
            ),

            const SizedBox(height: _DS.s16),

            // ── Back to login ──
            TextButton(
              onPressed: onBackToLogin,
              style: TextButton.styleFrom(
                foregroundColor: _DS.textSecondary,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Back to Login',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  final String number;
  final String text;
  const _Instruction({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 26, height: 26,
        decoration: const BoxDecoration(
            color: Color(0xFFFFF0E6), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(number,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: _DS.primary)),
      ),
      const SizedBox(width: _DS.s12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: _DS.textPrimary, height: 1.4)),
        ),
      ),
    ]);
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: _DS.s16, vertical: _DS.s12),
      decoration: BoxDecoration(
        color: isError ? _DS.errorSurface : _DS.successSurface,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(
            color: (isError ? _DS.error : _DS.success).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: isError ? _DS.error : _DS.success,
          size: 18,
        ),
        const SizedBox(width: _DS.s8),
        Expanded(
          child: Text(message,
              style: TextStyle(
                  color: isError ? _DS.error : _DS.success,
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }
}
