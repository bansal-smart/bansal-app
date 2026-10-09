import 'package:flutter/material.dart';

// ── Design tokens — mirrors lib/features/tests/test_response_sheet_screen.dart's DS class ──
abstract class _DS {
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
}

/// Loading placeholder for [TestResponseSheetScreen] — mirrors its exact
/// section layout (filter chip row, header card, per-question cards with
/// badge row + question text/image + option rows) so the page doesn't
/// visibly jump once real data arrives.
class TestResponseSheetSkeleton extends StatefulWidget {
  const TestResponseSheetSkeleton({super.key});

  @override
  State<TestResponseSheetSkeleton> createState() =>
      _TestResponseSheetSkeletonState();
}

class _TestResponseSheetSkeletonState extends State<TestResponseSheetSkeleton>
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
      color: Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                _ShimmerBox(
                  controller: _ctrl,
                  width: 64,
                  height: 30,
                  radius: 999,
                ),
                const SizedBox(width: 8),
                _ShimmerBox(
                  controller: _ctrl,
                  width: 84,
                  height: 30,
                  radius: 999,
                ),
                const SizedBox(width: 8),
                _ShimmerBox(
                  controller: _ctrl,
                  width: 76,
                  height: 30,
                  radius: 999,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                _HeaderCardSkeleton(controller: _ctrl),
                const SizedBox(height: 14),
                _QuestionCardSkeleton(controller: _ctrl),
                const SizedBox(height: 12),
                _QuestionCardSkeleton(controller: _ctrl),
                const SizedBox(height: 12),
                _QuestionCardSkeleton(controller: _ctrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header card (title + subtitle) ──────────────────────────────────────
class _HeaderCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _HeaderCardSkeleton({required this.controller});

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
          _ShimmerBox(
            controller: controller,
            width: 180,
            height: 16,
            radius: 4,
          ),
          const SizedBox(height: 8),
          _ShimmerBox(
            controller: controller,
            width: double.infinity,
            height: 11,
            radius: 4,
          ),
          const SizedBox(height: 6),
          _ShimmerBox(
            controller: controller,
            width: 220,
            height: 11,
            radius: 4,
          ),
        ],
      ),
    );
  }
}

// ── Per-question card (badge row + question + image + 4 options) ───────
class _QuestionCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _QuestionCardSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(
                controller: controller,
                width: 34,
                height: 20,
                radius: 999,
              ),
              const SizedBox(width: 8),
              _ShimmerBox(
                controller: controller,
                width: 50,
                height: 11,
                radius: 4,
              ),
              const Spacer(),
              _ShimmerBox(
                controller: controller,
                width: 64,
                height: 20,
                radius: 999,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ShimmerBox(
            controller: controller,
            width: double.infinity,
            height: 13,
            radius: 4,
          ),
          const SizedBox(height: 6),
          _ShimmerBox(
            controller: controller,
            width: 220,
            height: 13,
            radius: 4,
          ),
          const SizedBox(height: 10),
          _ShimmerBox(
            controller: controller,
            width: double.infinity,
            height: 120,
            radius: 12,
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ShimmerBox(
                controller: controller,
                width: double.infinity,
                height: 40,
                radius: 10,
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
