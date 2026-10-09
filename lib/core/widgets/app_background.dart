import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The Figma screen background (assets/video/bg_screen.mp4): an off-white
/// canvas with alternating blue and peach circles. Paints opaquely, so a
/// route wrapped in it never shows the route underneath during transitions.
///
/// Wrap a whole Scaffold (with a transparent `backgroundColor`) so the circles
/// sit behind the app bar as well as the body.
///
/// With an [introKey], the circles fade in one by one, top to bottom, exactly
/// as in bg_screen.mp4 — drawn in code rather than decoded from the video, so
/// it stays sharp at any screen size and costs nothing once it has finished.
/// Whenever [introKey] changes the intro replays from a blank canvas: the tab
/// shell passes the current tab, so — as in reference_video.mp4 — every tab
/// switch starts with an empty background and the bubbles fade in again.
class AppBackground extends StatefulWidget {
  final Widget child;

  /// Non-null enables the bubble intro; a new value replays it.
  final Object? introKey;

  const AppBackground({super.key, required this.child, this.introKey});

  @override
  State<AppBackground> createState() => _AppBackgroundState();
}

class _AppBackgroundState extends State<AppBackground>
    with SingleTickerProviderStateMixin {
  /// Length of bg_screen.mp4.
  static const _introLength = Duration(milliseconds: 2030);

  AnimationController? _intro;

  bool get _motionAllowed => !MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.introKey != null && _intro == null && _motionAllowed) {
      _intro = AnimationController(vsync: this, duration: _introLength)
        ..forward();
    }
  }

  @override
  void didUpdateWidget(covariant AppBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new tab: restart the bubbles from a blank background. Only the
    // background layer repaints while it runs (see build).
    if (widget.introKey != oldWidget.introKey && _motionAllowed) {
      (_intro ??= AnimationController(
        vsync: this,
        duration: _introLength,
      )).forward(from: 0);
    }
  }

  @override
  void dispose() {
    _intro?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Background and content sit in separate repaint layers: while the intro
    // runs only the background layer repaints, never the screen above it.
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(painter: _CirclesPainter(_intro), isComplex: true),
        ),
        RepaintBoundary(child: widget.child),
      ],
    );
  }
}

/// Puts [AppBackground] under every page route, then defers to the platform's
/// usual transition. Any screen with a transparent Scaffold gets the shared
/// background; screens with their own opaque colour (video, live, auth) cover
/// it as before.
class BackgroundPageTransitionsBuilder extends PageTransitionsBuilder {
  final PageTransitionsBuilder inner;
  const BackgroundPageTransitionsBuilder(this.inner);

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      inner.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      AppBackground(child: child),
    );
  }
}

class _CirclesPainter extends CustomPainter {
  /// Intro progress (0 → 1 over bg_screen.mp4's 2.03s); null = fully drawn.
  final Animation<double>? intro;

  _CirclesPainter(this.intro) : super(repaint: intro);

  // Circle bounds measured from the 395 × 858 reference frame (bg_screen.mp4
  // is 402 × 874, the same proportions and final layout).
  static const _frame = Size(395, 858);
  static const _circles = <(Rect, Color)>[
    (Rect.fromLTRB(227, 84, 364, 229), AppColors.bgBlue),
    (Rect.fromLTRB(90, 206, 206, 323), AppColors.bgPeach),
    (Rect.fromLTRB(232, 344, 352, 472), AppColors.bgBlue),
    (Rect.fromLTRB(89, 487, 190, 590), AppColors.bgPeach),
    (Rect.fromLTRB(212, 600, 333, 728), AppColors.bgBlue),
    (Rect.fromLTRB(86, 694, 187, 798), AppColors.bgPeach),
  ];

  // Fade schedule measured frame by frame from bg_screen.mp4: circle i starts
  // fading at 0.05s + i × 0.27s and reaches full colour 0.4s later, so the
  // last one settles at ~1.8s of the 2.03s clip. Nothing moves or scales.
  static const _firstStart = 50.0;
  static const _stagger = 270.0;
  static const _fade = 400.0;
  static const _clipMs = 2030.0;

  double _opacityOf(int i, double t) {
    final ms = t * _clipMs;
    final start = _firstStart + _stagger * i;
    return Curves.easeOut.transform(((ms - start) / _fade).clamp(0.0, 1.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    final t = intro?.value ?? 1.0;
    final sx = size.width / _frame.width;
    final sy = size.height / _frame.height;
    final paint = Paint()..isAntiAlias = true;
    for (var i = 0; i < _circles.length; i++) {
      final (rect, color) = _circles[i];
      final opacity = _opacityOf(i, t);
      if (opacity <= 0) continue;
      paint.color = color.withValues(alpha: color.a * opacity);
      canvas.drawOval(
        Rect.fromLTRB(
          rect.left * sx,
          rect.top * sy,
          rect.right * sx,
          rect.bottom * sy,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CirclesPainter oldDelegate) =>
      oldDelegate.intro != intro;
}
