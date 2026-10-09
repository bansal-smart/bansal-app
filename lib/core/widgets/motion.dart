import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Shared helpers for the tab entrance animations (paced from the Figma
/// prototype video) and tap feedback.
abstract class Motion {
  /// Honour the system "remove animations" accessibility setting.
  static bool off(BuildContext context) =>
      MediaQuery.of(context).disableAnimations;
}

extension MotionWidget on Widget {
  /// Applies [effects] unless the user has asked for reduced motion.
  Widget withMotion(BuildContext context, Widget Function(Animate a) effects) =>
      Motion.off(context) ? this : effects(animate());
}

extension MotionList on List<Widget> {
  /// Staggered cascade: each item fades in while sliding from the right,
  /// [interval] after the previous one.
  List<Widget> cascade(
    BuildContext context, {
    Duration delay = Duration.zero,
    Duration interval = const Duration(milliseconds: 100),
  }) => Motion.off(context)
      ? this
      : animate(delay: delay, interval: interval)
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
}

/// Tap feedback: the child shrinks slightly while a finger is down and
/// springs back on release. Uses a raw [Listener], so it never competes with
/// the child's own tap handling, and releases as soon as the finger starts
/// scrolling.
class Pressable extends StatefulWidget {
  final Widget child;

  /// Scale while pressed.
  final double pressedScale;

  const Pressable({super.key, required this.child, this.pressedScale = 0.96});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset? _origin;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _origin = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        final origin = _origin;
        if (origin != null && (e.position - origin).distance > kTouchSlop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
