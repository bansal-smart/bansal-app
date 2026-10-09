import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The Figma screen background: an off-white canvas with alternating blue and
/// peach circles. Paints opaquely, so a route wrapped in it never shows the
/// route underneath during transitions.
///
/// Wrap a whole Scaffold (with a transparent `backgroundColor`) so the circles
/// sit behind the app bar as well as the body.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CirclesPainter(),
      isComplex: true,
      willChange: false,
      child: child,
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
  const _CirclesPainter();

  // Circle bounds measured from the 395 × 858 reference frame.
  static const _frame = Size(395, 858);
  static const _circles = <(Rect, Color)>[
    (Rect.fromLTRB(227, 84, 364, 229), AppColors.bgBlue),
    (Rect.fromLTRB(90, 206, 206, 323), AppColors.bgPeach),
    (Rect.fromLTRB(232, 344, 352, 472), AppColors.bgBlue),
    (Rect.fromLTRB(89, 487, 190, 590), AppColors.bgPeach),
    (Rect.fromLTRB(212, 600, 333, 728), AppColors.bgBlue),
    (Rect.fromLTRB(86, 694, 187, 798), AppColors.bgPeach),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);
    final sx = size.width / _frame.width;
    final sy = size.height / _frame.height;
    final paint = Paint()..isAntiAlias = true;
    for (final (rect, color) in _circles) {
      paint.color = color;
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
  bool shouldRepaint(covariant _CirclesPainter oldDelegate) => false;
}
