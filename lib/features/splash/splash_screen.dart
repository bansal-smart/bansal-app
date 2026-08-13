import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../auth/data/auth_repository.dart';
import '../enrollments/data/repositories/enrollments_repository.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFFF97315);
  static const primaryDark = Color(0xFFE05A00);
  static const surface = Color(0xFFFFFFFF);
}

// ─────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Animation controllers ──────────────────────────────────────────────
  late final AnimationController _logoCtrl; // logo pop-in
  late final AnimationController _textCtrl; // text slide-up
  late final AnimationController _pulseCtrl; // glow ring pulse
  late final AnimationController _progressCtrl; // bottom progress bar
  late final AnimationController _dotsCtrl; // loading dots bounce
  late final AnimationController _ringCtrl; // rotating ring

  // ── Animations ─────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _pulseScale;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _brandOpacity;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _progress;
  late final Animation<double> _ringAngle;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // ── Logo pop (0 → 600ms) ──
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _logoScale = Tween<double>(
      begin: 0.30,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // ── Glow ring (fades in with logo, slightly delayed) ──
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // ── Pulsing ring (repeating) ──
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ── Rotating ring ──
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _ringAngle = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.linear));

    // ── Brand name slide-up (300 → 900ms) ──
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.40),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _brandOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.0, 0.7)),
    );

    // ── Tagline slide-up (staggered, 100ms after brand) ──
    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.60), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: const Interval(0.20, 0.90)),
    );

    // ── Progress bar (runs full 1400ms) ──
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _progress = CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOut);

    // ── Bouncing dots (repeating) ──
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  void _startSequence() async {
    // Give the widget tree a frame to settle
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Fire logo, progress and ring simultaneously
    _logoCtrl.forward();
    _progressCtrl.forward();

    // Text appears slightly after logo
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;
    _textCtrl.forward();

    // Route after total 1400ms
    await Future.delayed(const Duration(milliseconds: 1050));
    if (!mounted) return;
    _route();
  }

  void _route() async {
    if (!mounted) return;
    final prefs = ref.read(prefsProvider);
    final auth  = ref.read(authRepositoryProvider);
    if (!prefs.onboardingDone) {
      context.go('/onboarding');
    } else if (auth.isSignedIn && !prefs.profileSetupDone) {
      context.go('/profile-setup');
    } else {
      if (auth.isSignedIn && prefs.profileSetupDone) {
        // Re-run auto-enrollment on every launch so new free courses are picked up
        EnrollmentsRepository().autoEnrollFreeCourses(
          exam: prefs.userExam,
          userClass: prefs.userClass,
        );
      }
      context.go(auth.isSignedIn ? '/courses' : '/login');
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _dotsCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: DS.primaryDark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full gradient background ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFAA55),
                    Color(0xFFFF8C38),
                    DS.primary,
                    DS.primaryDark,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.25, 0.65, 1.0],
                ),
              ),
            ),

            // ── Decorative background circles ──
            Positioned(
              top: -100,
              left: -80,
              child: _GlowCircle(size: 320, opacity: 0.09),
            ),
            Positioned(
              top: 60,
              right: -60,
              child: _GlowCircle(size: 180, opacity: 0.07),
            ),
            Positioned(
              bottom: 80,
              left: -40,
              child: _GlowCircle(size: 200, opacity: 0.06),
            ),
            Positioned(
              bottom: -80,
              right: -60,
              child: _GlowCircle(size: 260, opacity: 0.08),
            ),

            // ── Grid dot pattern overlay ──
            const _DotPatternOverlay(),

            // ── Main content ──
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Logo section ──
                  _LogoSection(
                    logoScale: _logoScale,
                    logoOpacity: _logoOpacity,
                    glowOpacity: _glowOpacity,
                    pulseScale: _pulseScale,
                    ringAngle: _ringAngle,
                    ringCtrl: _ringCtrl,
                  ),

                  const SizedBox(height: 36),

                  // ── Brand name ──
                  FadeTransition(
                    opacity: _brandOpacity,
                    child: SlideTransition(
                      position: _brandSlide,
                      child: const Text(
                        'BANSAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Tagline ──
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: SlideTransition(
                      position: _taglineSlide,
                      child: Text(
                        'Learn. Compete. Achieve.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Loading dots ──
                  _LoadingDots(ctrl: _dotsCtrl),

                  const SizedBox(height: 20),

                  // ── Progress bar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _progress,
                          builder: (_, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: _progress.value,
                              minHeight: 3,
                              backgroundColor: Colors.white.withOpacity(0.18),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── "Powered by" footer ──
                  FadeTransition(
                    opacity: _taglineOpacity,
                    child: Text(
                      'Powered by Jeevijay Technologies',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGO SECTION (animated icon + rings)
// ─────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  final Animation<double> logoScale,
      logoOpacity,
      glowOpacity,
      pulseScale,
      ringAngle;
  final AnimationController ringCtrl;

  const _LogoSection({
    required this.logoScale,
    required this.logoOpacity,
    required this.glowOpacity,
    required this.pulseScale,
    required this.ringAngle,
    required this.ringCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Outermost glow halo ──
          FadeTransition(
            opacity: glowOpacity,
            child: ScaleTransition(
              scale: pulseScale,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
          ),

          // ── Middle frosted ring ──
          FadeTransition(
            opacity: glowOpacity,
            child: ScaleTransition(
              scale: pulseScale,
              child: Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.09),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // ── Rotating dashed arc ──
          FadeTransition(
            opacity: glowOpacity,
            child: AnimatedBuilder(
              animation: ringAngle,
              builder: (_, __) => Transform.rotate(
                angle: ringAngle.value,
                child: SizedBox(
                  width: 148,
                  height: 148,
                  child: CustomPaint(painter: _DashedArcPainter()),
                ),
              ),
            ),
          ),

          // ── Inner solid circle + icon ──
          ScaleTransition(
            scale: logoScale,
            child: FadeTransition(
              opacity: logoOpacity,
              child: Container(
                width: 106,
                height: 106,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: DS.primaryDark.withOpacity(0.30),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.school_rounded,
                    size: 52,
                    color: DS.primary,
                  ),
                ),
              ),
            ),
          ),

          // ── Sparkle dots around the ring ──
          FadeTransition(
            opacity: glowOpacity,
            child: AnimatedBuilder(
              animation: ringAngle,
              builder: (_, __) => SizedBox(
                width: 148,
                height: 148,
                child: CustomPaint(
                  painter: _SparklesPainter(angle: ringAngle.value),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOADING DOTS
// ─────────────────────────────────────────────
class _LoadingDots extends StatelessWidget {
  final AnimationController ctrl;
  const _LoadingDots({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value; // 0.0 → 1.0 repeating

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot: 0, 0.2, 0.4 phase offset
            final phase = (t - i * 0.22).clamp(0.0, 1.0);
            final bounce = math.sin(phase * math.pi); // 0 → 1 → 0
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.translate(
                offset: Offset(0, -8 * bounce),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.40 + 0.60 * bounce),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// GLOW CIRCLE
// ─────────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size, opacity;
  const _GlowCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

// ─────────────────────────────────────────────
// DOT PATTERN OVERLAY
// ─────────────────────────────────────────────
class _DotPatternOverlay extends StatelessWidget {
  const _DotPatternOverlay();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotGridPainter(), size: Size.infinite);
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.045)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const radius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// DASHED ARC PAINTER
// ─────────────────────────────────────────────
class _DashedArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    const dashCount = 16;
    const dashLength = 0.15; // radians
    const gapLength = 2 * math.pi / dashCount - dashLength;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (dashLength + gapLength);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashLength,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// SPARKLES PAINTER
// ─────────────────────────────────────────────
class _SparklesPainter extends CustomPainter {
  final double angle;
  const _SparklesPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // 4 sparkle dots at 90° intervals, rotating with the ring
    for (int i = 0; i < 4; i++) {
      final a = angle + i * (math.pi / 2);
      final x = center.dx + radius * math.cos(a);
      final y = center.dy + radius * math.sin(a);
      canvas.drawCircle(Offset(x, y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklesPainter old) => old.angle != angle;
}
