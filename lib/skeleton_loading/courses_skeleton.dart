import 'package:flutter/material.dart';

// ── Design tokens — mirrors lib/features/courses/courses_list_screen.dart's _C class ──
abstract class _DS {
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFF5F6FA);
  static const border = Color(0xFFE5E7EB);
}

/// Loading placeholder for [CoursesListScreen] — mirrors its exact section
/// layout (title, stats strip, continue-learning grid, all-courses grid) so
/// the page doesn't visibly jump once real data arrives.
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

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _DS.bg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ── Title + subtitle ──
            _ShimmerBox(controller: _ctrl, width: 160, height: 22, radius: 6),
            const SizedBox(height: 8),
            _ShimmerBox(controller: _ctrl, width: 220, height: 13, radius: 4),

            const SizedBox(height: 16),

            // ── Stats strip (2x2) ──
            Row(
              children: [
                Expanded(child: _StatTileSkeleton(controller: _ctrl)),
                const SizedBox(width: 12),
                Expanded(child: _StatTileSkeleton(controller: _ctrl)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatTileSkeleton(controller: _ctrl)),
                const SizedBox(width: 12),
                Expanded(child: _StatTileSkeleton(controller: _ctrl)),
              ],
            ),

            const SizedBox(height: 20),

            // ── Continue Learning ──
            _SectionTitleSkeleton(controller: _ctrl),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _CourseCardSkeleton(controller: _ctrl)),
                const SizedBox(width: 12),
                Expanded(child: _CourseCardSkeleton(controller: _ctrl)),
              ],
            ),

            const SizedBox(height: 20),

            // ── All My Courses ──
            _SectionTitleSkeleton(controller: _ctrl),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _CourseCardSkeleton(controller: _ctrl)),
                const SizedBox(width: 12),
                Expanded(child: _CourseCardSkeleton(controller: _ctrl)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _CourseCardSkeleton(controller: _ctrl)),
                const SizedBox(width: 12),
                Expanded(child: _CourseCardSkeleton(controller: _ctrl)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section title (colored bar + label) ─────────────────────────────────
class _SectionTitleSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _SectionTitleSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _DS.border,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        _ShimmerBox(controller: controller, width: 130, height: 15, radius: 4),
      ],
    );
  }
}

// ── Stats strip tile (icon + value + label) ─────────────────────────────
class _StatTileSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _StatTileSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DS.border),
      ),
      child: Row(
        children: [
          _ShimmerBox(controller: controller, width: 40, height: 40, radius: 10),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ShimmerBox(controller: controller, width: 30, height: 16, radius: 4),
                const SizedBox(height: 6),
                _ShimmerBox(controller: controller, width: 60, height: 10, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Course card (thumbnail + title/subtitle + progress bar) ─────────────
class _CourseCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _CourseCardSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _DS.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: _ShimmerBox(
              controller: controller,
              width: double.infinity,
              height: double.infinity,
              radius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(controller: controller, width: 60, height: 9, radius: 3),
                const SizedBox(height: 6),
                _ShimmerBox(
                  controller: controller,
                  width: double.infinity,
                  height: 13,
                  radius: 4,
                ),
                const SizedBox(height: 8),
                _ShimmerBox(
                  controller: controller,
                  width: double.infinity,
                  height: 5,
                  radius: 999,
                ),
              ],
            ),
          ),
        ],
      ),
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
