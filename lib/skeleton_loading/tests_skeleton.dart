import 'package:flutter/material.dart';

/// Loading placeholder for [TestsListScreen] — mirrors its layout (title,
/// navy hero with three stats, numbered test-type cards).
class TestsSkeleton extends StatefulWidget {
  const TestsSkeleton({super.key});

  @override
  State<TestsSkeleton> createState() => _TestsSkeletonState();
}

class _TestsSkeletonState extends State<TestsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _ShimmerBox(
            controller: _ctrl,
            width: 110,
            height: 22,
            radius: 6,
          ),
        ),
        const SizedBox(height: 18),
        _ShimmerBox(controller: _ctrl, height: 176, radius: 24, dark: true),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: _ShimmerBox(
            controller: _ctrl,
            width: 90,
            height: 14,
            radius: 4,
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _ShimmerBox(controller: _ctrl, height: 62, radius: 18),
        ],
      ],
    );
  }
}

// ── Shimmering placeholder box ──────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final AnimationController controller;
  final double? width;
  final double height;
  final double radius;
  final bool dark;

  const _ShimmerBox({
    required this.controller,
    this.width,
    required this.height,
    required this.radius,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = dark ? const Color(0xFF2B4A8F) : const Color(0xFFE9ECF1);
    final highlightColor = dark
        ? const Color(0xFF3D5FA6)
        : const Color(0xFFF6F7F9);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - controller.value * 2, 0),
              end: Alignment(1.0 - controller.value * 2, 0),
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
