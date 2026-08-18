import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import 'data/auth_repository.dart';

abstract class _DS {
  static const primary = Color(0xFF193F8F);
  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);

  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusXl = 28;
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

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
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetOtp(email);
      if (!mounted) return;
      context.push('/forgot-otp?email=${Uri.encodeComponent(email)}');
    } catch (e) {
      setState(() => _error = AppException.from(e).userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
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
                    child: _FormCard(
                      emailCtrl: _emailCtrl,
                      loading: _loading,
                      error: _error,
                      onSubmit: _loading ? null : _submit,
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
              border: Border.all(color: Colors.white.withValues(alpha:0.12), width: 2),
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
      color: Colors.white.withValues(alpha:opacity),
    ),
  );
}

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
              color: Colors.white.withValues(alpha:0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha:0.25), width: 1.5),
            ),
            child: const Icon(Icons.lock_reset_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: _DS.s20),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: -0.5, height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _DS.s8),
          Text(
            'Enter your email and we\'ll send\na 6-digit verification code',
            style: TextStyle(fontSize: 14.5, color: Colors.white.withValues(alpha:0.80), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final TextEditingController emailCtrl;
  final bool loading;
  final String? error;
  final VoidCallback? onSubmit;

  const _FormCard({
    required this.emailCtrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
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
        padding: const EdgeInsets.fromLTRB(_DS.s24, _DS.s32, _DS.s24, _DS.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Container(
                width: 4, height: 28,
                decoration: BoxDecoration(
                  color: _DS.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: _DS.s12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reset Password',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _DS.textPrimary, letterSpacing: -0.3),
                ),
                Text('We\'ll send a code to your email',
                  style: TextStyle(fontSize: 12.5, color: _DS.textSecondary),
                ),
              ]),
            ]),

            const SizedBox(height: _DS.s28),

            // Email field
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 15, color: _DS.textPrimary, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'you@example.com',
                labelStyle: const TextStyle(color: _DS.textSecondary, fontSize: 14),
                hintStyle: const TextStyle(color: _DS.textHint, fontSize: 14),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: _DS.s4),
                  child: Icon(Icons.mail_outline_rounded, size: 20, color: _DS.textSecondary),
                ),
                filled: true,
                fillColor: _DS.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: _DS.s16, vertical: _DS.s16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.border, width: 1.2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.primary, width: 1.8)),
                errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.error, width: 1.2)),
              ),
            ),

            const SizedBox(height: _DS.s20),

            if (error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: _DS.s16, vertical: _DS.s12),
                decoration: BoxDecoration(
                  color: _DS.errorSurface,
                  borderRadius: BorderRadius.circular(_DS.radiusSm),
                  border: Border.all(color: _DS.error.withValues(alpha:0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: _DS.error, size: 18),
                  const SizedBox(width: _DS.s8),
                  Expanded(child: Text(error!, style: const TextStyle(color: _DS.error, fontSize: 13, fontWeight: FontWeight.w500))),
                ]),
              ),
              const SizedBox(height: _DS.s16),
            ],

            // Send OTP button
            SizedBox(
              height: 54,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: onSubmit == null ? null : const LinearGradient(
                    colors: [Color(0xFF2B5BB8), _DS.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(_DS.radiusMd),
                  boxShadow: onSubmit == null ? [] : [
                    BoxShadow(color: _DS.primary.withValues(alpha:0.35), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _DS.border,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusMd)),
                  ),
                  child: loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Send Verification Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ),
              ),
            ),

            const SizedBox(height: _DS.s24),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Remember your password? ', style: TextStyle(color: _DS.textSecondary, fontSize: 14)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: const Text('Login', style: TextStyle(color: _DS.primary, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
