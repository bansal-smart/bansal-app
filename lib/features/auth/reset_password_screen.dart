import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import 'data/auth_repository.dart';
import '../../core/providers.dart';

abstract class _DS {
  static const primary = Color(0xFFF97315);
  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
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
  static const double s28 = 28;
  static const double s32 = 32;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusXl = 28;
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// 'signup' → redirect to /home after password set
  /// 'forgot' (default) → redirect to /login after password set
  final String source;
  const ResetPasswordScreen({super.key, this.source = 'forgot'});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  late AnimationController _ctrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heroFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));
    _cardFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 0.9, curve: Curves.easeOut));
    _ctrl.forward();
    // Pre-fill password from signup form so student doesn't retype it
    if (widget.source == 'signup') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final pending = ref.read(authRepositoryProvider).pendingPassword;
        if (pending != null && pending.isNotEmpty) {
          _passwordCtrl.text = pending;
          _confirmCtrl.text = pending;
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_passwordCtrl.text);
      ref.read(authRepositoryProvider).pendingPassword = null;
      if (!mounted) return;
      if (widget.source == 'signup') {
        ref.read(passwordResetInProgressProvider.notifier).state = false;
        context.go('/home');
      } else {
        // Forgot password — sign out so student logs in fresh
        await ref.read(authRepositoryProvider).signOut();
        if (!mounted) return;
        ref.read(passwordResetInProgressProvider.notifier).state = false;
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password created! Please log in.'),
            backgroundColor: _DS.success,
          ),
        );
      }
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
                    child: _HeroSection(isSignup: widget.source == 'signup'),
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
                      formKey: _form,
                      passwordCtrl: _passwordCtrl,
                      confirmCtrl: _confirmCtrl,
                      loading: _loading,
                      error: _error,
                      obscurePassword: _obscurePassword,
                      obscureConfirm: _obscureConfirm,
                      isSignup: widget.source == 'signup',
                      onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                      onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
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

class _HeroSection extends StatelessWidget {
  final bool isSignup;
  const _HeroSection({required this.isSignup});
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
              border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
            ),
            child: const Icon(Icons.lock_open_rounded, size: 40, color: Colors.white),
          ),
          const SizedBox(height: _DS.s20),
          Text(
            isSignup ? 'Create Password' : 'Reset Password',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5, height: 1.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _DS.s8),
          Text(
            isSignup
                ? 'Set a password to secure\nyour Bansal account.'
                : 'Your identity is verified.\nSet a strong new password.',
            style: TextStyle(fontSize: 14.5, color: Colors.white.withValues(alpha: 0.80), height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmCtrl;
  final bool loading;
  final String? error;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool isSignup;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback? onSubmit;

  const _FormCard({
    required this.formKey,
    required this.passwordCtrl,
    required this.confirmCtrl,
    required this.loading,
    required this.error,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.isSignup,
    required this.onTogglePassword,
    required this.onToggleConfirm,
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
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(width: 4, height: 28,
                  decoration: BoxDecoration(color: _DS.primary, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: _DS.s12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isSignup ? 'Create Password' : 'New Password',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _DS.textPrimary, letterSpacing: -0.3),
                  ),
                  Text('Must be at least 8 characters',
                    style: TextStyle(fontSize: 12.5, color: _DS.textSecondary),
                  ),
                ]),
              ]),

              const SizedBox(height: _DS.s28),

              // Password field
              TextFormField(
                controller: passwordCtrl,
                obscureText: obscurePassword,
                validator: (v) {
                  if (v == null || v.length < 8) return 'Minimum 8 characters';
                  return null;
                },
                style: const TextStyle(fontSize: 15, color: _DS.textPrimary, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: '••••••••',
                  labelStyle: const TextStyle(color: _DS.textSecondary, fontSize: 14),
                  hintStyle: const TextStyle(color: _DS.textHint, fontSize: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: _DS.s4),
                    child: Icon(Icons.lock_outline_rounded, size: 20, color: _DS.textSecondary),
                  ),
                  suffixIcon: GestureDetector(
                    onTap: onTogglePassword,
                    child: Padding(
                      padding: const EdgeInsets.all(_DS.s12),
                      child: Icon(
                        obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20, color: _DS.textSecondary,
                      ),
                    ),
                  ),
                  filled: true,
                  fillColor: _DS.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: _DS.s16, vertical: _DS.s16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.border, width: 1.2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.primary, width: 1.8)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.error, width: 1.2)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.error, width: 1.8)),
                  errorStyle: const TextStyle(color: _DS.error, fontSize: 12),
                ),
              ),

              const SizedBox(height: _DS.s16),

              // Confirm password field
              TextFormField(
                controller: confirmCtrl,
                obscureText: obscureConfirm,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != passwordCtrl.text) return 'Passwords do not match';
                  return null;
                },
                style: const TextStyle(fontSize: 15, color: _DS.textPrimary, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  hintText: '••••••••',
                  labelStyle: const TextStyle(color: _DS.textSecondary, fontSize: 14),
                  hintStyle: const TextStyle(color: _DS.textHint, fontSize: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: _DS.s4),
                    child: Icon(Icons.lock_outline_rounded, size: 20, color: _DS.textSecondary),
                  ),
                  suffixIcon: GestureDetector(
                    onTap: onToggleConfirm,
                    child: Padding(
                      padding: const EdgeInsets.all(_DS.s12),
                      child: Icon(
                        obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20, color: _DS.textSecondary,
                      ),
                    ),
                  ),
                  filled: true,
                  fillColor: _DS.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: _DS.s16, vertical: _DS.s16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.border, width: 1.2)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.primary, width: 1.8)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.error, width: 1.2)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(_DS.radiusMd), borderSide: const BorderSide(color: _DS.error, width: 1.8)),
                  errorStyle: const TextStyle(color: _DS.error, fontSize: 12),
                ),
              ),

              const SizedBox(height: _DS.s20),

              // Password strength hints
              Container(
                padding: const EdgeInsets.all(_DS.s12),
                decoration: BoxDecoration(
                  color: _DS.successSurface,
                  borderRadius: BorderRadius.circular(_DS.radiusSm),
                  border: Border.all(color: _DS.success.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: _DS.success),
                      const SizedBox(width: _DS.s8),
                      Text('Password tips', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _DS.success)),
                    ]),
                    const SizedBox(height: _DS.s4),
                    Text('• At least 8 characters\n• Mix of letters and numbers recommended',
                      style: TextStyle(fontSize: 11.5, color: _DS.success, height: 1.6),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: _DS.s20),

              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: _DS.s16, vertical: _DS.s12),
                  decoration: BoxDecoration(
                    color: _DS.errorSurface,
                    borderRadius: BorderRadius.circular(_DS.radiusSm),
                    border: Border.all(color: _DS.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: _DS.error, size: 18),
                    const SizedBox(width: _DS.s8),
                    Expanded(child: Text(error!, style: const TextStyle(color: _DS.error, fontSize: 13, fontWeight: FontWeight.w500))),
                  ]),
                ),
                const SizedBox(height: _DS.s16),
              ],

              // Update password button
              SizedBox(
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: onSubmit == null ? null : const LinearGradient(
                      colors: [Color(0xFFFF8C38), _DS.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(_DS.radiusMd),
                    boxShadow: onSubmit == null ? [] : [
                      BoxShadow(color: _DS.primary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
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
                        : Text(isSignup ? 'Create Password' : 'Update Password', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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
