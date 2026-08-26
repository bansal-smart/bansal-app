import 'package:flutter/material.dart';

// ── Design tokens — mirrors lib/features/home/home_screen.dart's DS class ──
abstract class _DS {
  static const background = Color(0xFFF7F8FA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);

  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
}

/// Loading placeholder for [HomeScreen] — mirrors its exact section layout
/// (banner carousel, quick actions grid, progress grid, today card, continue
/// learning card) so the page doesn't visibly jump once real data arrives.
class HomeSkeleton extends StatefulWidget {
  const HomeSkeleton({super.key});

  @override
  State<HomeSkeleton> createState() => _HomeSkeletonState();
}

class _HomeSkeletonState extends State<HomeSkeleton>
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
        padding: const EdgeInsets.fromLTRB(
          _DS.s16,
          _DS.s16,
          _DS.s16,
          _DS.s32,
        ),
        children: [
// ── Banner carousel ────────────────────────────────────────────────────────
          _BannerCarouselSkeleton(controller: _ctrl),

          const SizedBox(height: _DS.s16),

          // ── Quick action grid (2x2) ──
          Row(
            children: [
              Expanded(child: _ActionTileSkeleton(controller: _ctrl)),
              const SizedBox(width: _DS.s12),
              Expanded(child: _ActionTileSkeleton(controller: _ctrl)),
            ],
          ),
          const SizedBox(height: _DS.s12),
          Row(
            children: [
              Expanded(child: _ActionTileSkeleton(controller: _ctrl)),
              const SizedBox(width: _DS.s12),
              Expanded(child: _ActionTileSkeleton(controller: _ctrl)),
            ],
          ),

          const SizedBox(height: _DS.s24),

          // ── My Progress ──
          _SectionHeaderSkeleton(controller: _ctrl),
          const SizedBox(height: _DS.s12),
          Row(
            children: [
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
              const SizedBox(width: _DS.s12),
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
            ],
          ),
          const SizedBox(height: _DS.s12),
          Row(
            children: [
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
              const SizedBox(width: _DS.s12),
              Expanded(child: _StatTileSkeleton(controller: _ctrl)),
            ],
          ),

          const SizedBox(height: _DS.s24),

          // ── Today ──
          _SectionHeaderSkeleton(controller: _ctrl),
          const SizedBox(height: _DS.s12),
          _ShimmerBox(
            controller: _ctrl,
            height: 140,
            radius: _DS.radiusLg,
            bordered: true,
          ),

          const SizedBox(height: _DS.s24),

          // ── Continue Learning ──
          _SectionHeaderSkeleton(controller: _ctrl),
          const SizedBox(height: _DS.s12),
          _ContinueLearningSkeleton(controller: _ctrl),
        ],
      ),
    );
  }
}

// ── Banner carousel ────────────────────────────────────────────────────────
class _BannerCarouselSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _BannerCarouselSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_DS.radiusLg),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - controller.value * 2, 0),
              end: Alignment(1.0 - controller.value * 2, 0),
              colors: const [
                Color(0xFFE9ECF1),
                Color(0xFFF6F7F9),
                Color(0xFFE9ECF1),
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section header (title + subtitle + trailing action label) ─────────────
class _SectionHeaderSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _SectionHeaderSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(
                controller: controller,
                width: 120,
                height: 16,
                radius: _DS.radiusSm,
              ),
              const SizedBox(height: 6),
              _ShimmerBox(
                controller: controller,
                width: 180,
                height: 12,
                radius: _DS.radiusSm,
              ),
            ],
          ),
        ),
        const SizedBox(width: _DS.s8),
        _ShimmerBox(
          controller: controller,
          width: 70,
          height: 14,
          radius: _DS.radiusSm,
        ),
      ],
    );
  }
}

// ── Quick-action tile (icon + title + subtitle) ────────────────────────────
class _ActionTileSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _ActionTileSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_DS.s16),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: _DS.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
            controller: controller,
            width: 40,
            height: 40,
            radius: _DS.radiusMd,
          ),
          const SizedBox(height: _DS.s12),
          _ShimmerBox(
            controller: controller,
            width: 80,
            height: 13,
            radius: _DS.radiusSm,
          ),
          const SizedBox(height: 6),
          _ShimmerBox(
            controller: controller,
            width: 60,
            height: 10,
            radius: _DS.radiusSm,
          ),
        ],
      ),
    );
  }
}

// ── Progress stat tile (icon + big value + label) ──────────────────────────
class _StatTileSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _StatTileSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_DS.s16),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: _DS.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShimmerBox(
            controller: controller,
            width: 34,
            height: 34,
            radius: _DS.radiusSm,
          ),
          const SizedBox(height: _DS.s10),
          _ShimmerBox(
            controller: controller,
            width: 44,
            height: 18,
            radius: _DS.radiusSm,
          ),
          const SizedBox(height: 6),
          _ShimmerBox(
            controller: controller,
            width: 70,
            height: 10,
            radius: _DS.radiusSm,
          ),
        ],
      ),
    );
  }
}

// ── Continue Learning card (thumbnail + title + subtitle + chevron) ────────
class _ContinueLearningSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _ContinueLearningSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_DS.s14),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: _DS.border, width: 1.2),
      ),
      child: Row(
        children: [
          _ShimmerBox(
            controller: controller,
            width: 56,
            height: 56,
            radius: _DS.radiusMd,
          ),
          const SizedBox(width: _DS.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  controller: controller,
                  width: double.infinity,
                  height: 14,
                  radius: _DS.radiusSm,
                ),
                const SizedBox(height: 6),
                _ShimmerBox(
                  controller: controller,
                  width: 140,
                  height: 11,
                  radius: _DS.radiusSm,
                ),
              ],
            ),
          ),
          const SizedBox(width: _DS.s8),
          _ShimmerBox(controller: controller, width: 14, height: 14, radius: 4),
        ],
      ),
    );
  }
}

// ── Shimmering placeholder box ──────────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final AnimationController controller;
  final double? width;
  final double height;
  final double radius;
  final bool bordered;

  const _ShimmerBox({
    required this.controller,
    this.width,
    required this.height,
    required this.radius,
    this.bordered = false,
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
            border: bordered
                ? Border.all(color: _DS.border, width: 1.2)
                : null,
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
