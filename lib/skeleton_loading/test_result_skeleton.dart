import 'package:flutter/material.dart';

// ── Design tokens — mirrors lib/features/tests/test_result_screen.dart's DS class ──
abstract class _DS {
  static const primaryDark = Color(0xFF102A63);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFFFFBF8);
  static const border = Color(0xFFE5E7EB);
}

/// Loading placeholder for [TestResultScreen] — mirrors its exact section
/// layout (score hero, locked rank card, stat grid, scorecard card, chart
/// cards, subject table, action buttons) so the page doesn't visibly jump
/// once real data arrives.
class TestResultSkeleton extends StatefulWidget {
  const TestResultSkeleton({super.key});

  @override
  State<TestResultSkeleton> createState() => _TestResultSkeletonState();
}

class _TestResultSkeletonState extends State<TestResultSkeleton>
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _ScoreHeroSkeleton(controller: _ctrl),
          const SizedBox(height: 16),
          _LockedCardSkeleton(controller: _ctrl),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
              const SizedBox(width: 10),
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
              const SizedBox(width: 10),
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
            ],
          ),
          const SizedBox(height: 16),
          _ScorecardSkeleton(controller: _ctrl),
          const SizedBox(height: 16),
          _ChartCardSkeleton(controller: _ctrl, height: 220),
          const SizedBox(height: 16),
          _ChartCardSkeleton(controller: _ctrl, height: 240),
          const SizedBox(height: 16),
          _SubjectTableSkeleton(controller: _ctrl),
          const SizedBox(height: 16),
          _ShimmerBox(controller: _ctrl, width: double.infinity, height: 48, radius: 14),
          const SizedBox(height: 16),
          _ShimmerBox(controller: _ctrl, width: double.infinity, height: 90, radius: 20),
          const SizedBox(height: 16),
          _ShimmerBox(controller: _ctrl, width: double.infinity, height: 48, radius: 14),
          const SizedBox(height: 10),
          _ShimmerBox(controller: _ctrl, width: double.infinity, height: 48, radius: 14),
        ],
      ),
    );
  }
}

// ── Score hero (navy gradient card) ─────────────────────────────────────
class _ScoreHeroSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _ScoreHeroSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B5BB8), _DS.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          _ShimmerBox(controller: controller, width: 100, height: 22, radius: 999, dark: true),
          const SizedBox(height: 14),
          _ShimmerBox(controller: controller, width: 160, height: 18, radius: 5, dark: true),
          const SizedBox(height: 20),
          _ShimmerBox(controller: controller, width: 70, height: 11, radius: 4, dark: true),
          const SizedBox(height: 8),
          _ShimmerBox(controller: controller, width: 120, height: 40, radius: 8, dark: true),
          const SizedBox(height: 6),
          _ShimmerBox(controller: controller, width: 90, height: 11, radius: 4, dark: true),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HeroStatSkeleton(controller: controller),
              _HeroStatSkeleton(controller: controller),
              _HeroStatSkeleton(controller: controller),
            ],
          ),
          const SizedBox(height: 14),
          _ShimmerBox(controller: controller, width: 180, height: 11, radius: 4, dark: true),
        ],
      ),
    );
  }
}

class _HeroStatSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _HeroStatSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ShimmerBox(controller: controller, width: 18, height: 18, radius: 999, dark: true),
        const SizedBox(height: 6),
        _ShimmerBox(controller: controller, width: 30, height: 14, radius: 4, dark: true),
        const SizedBox(height: 4),
        _ShimmerBox(controller: controller, width: 44, height: 10, radius: 4, dark: true),
      ],
    );
  }
}

// ── Locked rank card ─────────────────────────────────────────────────────
class _LockedCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _LockedCardSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border),
      ),
      child: Column(
        children: [
          _ShimmerBox(controller: controller, width: 44, height: 44, radius: 999),
          const SizedBox(height: 12),
          _ShimmerBox(controller: controller, width: 220, height: 13, radius: 4),
          const SizedBox(height: 8),
          _ShimmerBox(controller: controller, width: 180, height: 11, radius: 4),
        ],
      ),
    );
  }
}

// ── 2x2 stat tile (icon + value + label) ────────────────────────────────
class _StatTileSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _StatTileSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ShimmerBox(controller: controller, width: 30, height: 30, radius: 999),
          const SizedBox(height: 8),
          _ShimmerBox(controller: controller, width: 34, height: 18, radius: 4),
          const SizedBox(height: 4),
          _ShimmerBox(controller: controller, width: 60, height: 10, radius: 4),
        ],
      ),
    );
  }
}

// ── Scorecard PDF card ────────────────────────────────────────────────────
class _ScorecardSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _ScorecardSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(controller: controller, width: 110, height: 14, radius: 4),
          const SizedBox(height: 6),
          _ShimmerBox(controller: controller, width: 200, height: 11, radius: 4),
          const SizedBox(height: 14),
          _ShimmerBox(controller: controller, width: double.infinity, height: 44, radius: 14),
        ],
      ),
    );
  }
}

// ── Chart card (title + chart placeholder + legend) ─────────────────────
class _ChartCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  final double height;
  const _ChartCardSkeleton({required this.controller, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(controller: controller, width: 150, height: 14, radius: 4),
          const SizedBox(height: 16),
          _ShimmerBox(controller: controller, width: double.infinity, height: height, radius: 12),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ShimmerBox(controller: controller, width: 60, height: 10, radius: 4),
              const SizedBox(width: 16),
              _ShimmerBox(controller: controller, width: 60, height: 10, radius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Subject-wise breakdown table ─────────────────────────────────────────
class _SubjectTableSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _SubjectTableSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(controller: controller, width: 170, height: 14, radius: 4),
          const SizedBox(height: 16),
          _ShimmerBox(controller: controller, width: double.infinity, height: 20, radius: 4),
          const SizedBox(height: 12),
          _ShimmerBox(controller: controller, width: double.infinity, height: 16, radius: 4),
          const SizedBox(height: 10),
          _ShimmerBox(controller: controller, width: double.infinity, height: 16, radius: 4),
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
