import 'package:flutter/material.dart';

/// Loading placeholder for [CoursesListScreen] — mirrors its section layout
/// (title, overview card, continue-learning card, subject rows) so the page
/// doesn't visibly jump once real data arrives.
class CoursesSkeleton extends StatefulWidget {
  const CoursesSkeleton({super.key});

  @override
  State<CoursesSkeleton> createState() => _CoursesSkeletonState();
}

class _CoursesSkeletonState extends State<CoursesSkeleton>
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

  Widget _sectionTitle() => Align(
    alignment: Alignment.centerLeft,
    child: _ShimmerBox(controller: _ctrl, width: 140, height: 14, radius: 4),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // ── Title ──
        Align(
          alignment: Alignment.centerLeft,
          child: _ShimmerBox(
            controller: _ctrl,
            width: 140,
            height: 22,
            radius: 6,
          ),
        ),
        const SizedBox(height: 18),

        // ── Overview card ──
        _ShimmerBox(controller: _ctrl, height: 190, radius: 26),
        const SizedBox(height: 28),

        // ── Continue Learning ──
        _sectionTitle(),
        const SizedBox(height: 14),
        _ShimmerBox(controller: _ctrl, height: 114, radius: 26),
        const SizedBox(height: 28),

        // ── Subjects ──
        _sectionTitle(),
        const SizedBox(height: 14),
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _ShimmerBox(controller: _ctrl, height: 68, radius: 22),
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

  const _ShimmerBox({
    required this.controller,
    this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFFE9ECF1);
    const highlightColor = Color(0xFFF6F7F9);

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
              colors: const [baseColor, highlightColor, baseColor],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
