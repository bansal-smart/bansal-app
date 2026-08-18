import 'package:flutter/material.dart';

// ── Design tokens — mirrors lib/features/tests/tests_list_screen.dart's DS class ──
abstract class _DS {
  static const primary = Color(0xFF193F8F);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFBF8);
  static const border = Color(0xFFE5E7EB);
}

/// Loading placeholder for [TestsListScreen] — mirrors its exact section
/// layout (navy header, search bar, collapsible group cards with test rows)
/// so the page doesn't visibly jump once real data arrives.
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
    return ColoredBox(
      color: _DS.background,
      child: Column(
        children: [
          _HeaderSkeleton(controller: _ctrl),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _GroupCardSkeleton(controller: _ctrl, rowCount: 2),
                const SizedBox(height: 14),
                _GroupCardSkeleton(controller: _ctrl, rowCount: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header (title + count + search bar) on solid navy ──────────────────
class _HeaderSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _HeaderSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _DS.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(controller: controller, width: 150, height: 22, radius: 6, dark: true),
              const SizedBox(height: 8),
              _ShimmerBox(controller: controller, width: 120, height: 13, radius: 4, dark: true),
              const SizedBox(height: 16),
              _ShimmerBox(
                controller: controller,
                width: double.infinity,
                height: 46,
                radius: 999,
                dark: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Collapsible group card (icon tile + label, then N test rows) ───────
class _GroupCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  final int rowCount;
  const _GroupCardSkeleton({required this.controller, required this.rowCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _ShimmerBox(controller: controller, width: 40, height: 40, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(controller: controller, width: 130, height: 14, radius: 4),
                      const SizedBox(height: 6),
                      _ShimmerBox(controller: controller, width: 60, height: 11, radius: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _DS.border),
          for (int i = 0; i < rowCount; i++) ...[
            if (i > 0) const Divider(height: 1, color: _DS.border),
            _TestRowSkeleton(controller: controller),
          ],
        ],
      ),
    );
  }
}

// ── Test row (icon tile + badge/title/meta, trailing status/chevron) ───
class _TestRowSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _TestRowSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(controller: controller, width: 40, height: 40, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(controller: controller, width: 80, height: 9, radius: 3),
                const SizedBox(height: 6),
                _ShimmerBox(controller: controller, width: double.infinity, height: 13, radius: 4),
                const SizedBox(height: 6),
                _ShimmerBox(controller: controller, width: 150, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ShimmerBox(controller: controller, width: 60, height: 22, radius: 999),
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
    final highlightColor = dark ? const Color(0xFF3D5FA6) : const Color(0xFFF6F7F9);

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
