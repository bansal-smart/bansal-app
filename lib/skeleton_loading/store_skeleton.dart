import 'package:flutter/material.dart';

/// Loading placeholder for [StoreScreen] — mirrors its layout (title, navy
/// E-Store hero, search bar, category band, Books / Module Packs toggle and
/// the two-column product grid) so the page doesn't jump once data arrives.
class StoreSkeleton extends StatefulWidget {
  const StoreSkeleton({super.key});

  @override
  State<StoreSkeleton> createState() => _StoreSkeletonState();
}

class _StoreSkeletonState extends State<StoreSkeleton>
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

  Widget _label(double width) => Align(
    alignment: Alignment.centerLeft,
    child: _ShimmerBox(controller: _ctrl, width: width, height: 13, radius: 4),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──
              Align(
                alignment: Alignment.centerLeft,
                child: _ShimmerBox(
                  controller: _ctrl,
                  width: 170,
                  height: 22,
                  radius: 6,
                ),
              ),
              const SizedBox(height: 18),

              // ── E-Store hero ──
              _ShimmerBox(
                controller: _ctrl,
                height: 112,
                radius: 24,
                dark: true,
              ),
              const SizedBox(height: 22),

              // ── Search bar ──
              _ShimmerBox(controller: _ctrl, height: 50, radius: 16),
              const SizedBox(height: 26),

              _label(100),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // ── Category band ──
        Container(
          color: const Color(0xB3FCE6D2),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 18),
                _ShimmerBox(
                  controller: _ctrl,
                  width: i == 0 ? 56 : 82,
                  height: 24,
                  radius: 12,
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Books / Module Packs toggle ──
              _ShimmerBox(controller: _ctrl, height: 46, radius: 6),
              const SizedBox(height: 30),

              _label(160),
              const SizedBox(height: 14),

              // ── Product grid (2 x 2) ──
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _ProductCardSkeleton(controller: _ctrl)),
                    const SizedBox(width: 14),
                    Expanded(child: _ProductCardSkeleton(controller: _ctrl)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Product card (cover + tag, title, author, price/cart, link) ──────────
class _ProductCardSkeleton extends StatelessWidget {
  final AnimationController controller;
  const _ProductCardSkeleton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // Same proportions as the real grid (childAspectRatio: 0.56).
      aspectRatio: 0.56,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFE9F0FB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _ShimmerBox(
                controller: controller,
                height: double.infinity,
                radius: 0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerBox(
                    controller: controller,
                    width: 40,
                    height: 9,
                    radius: 3,
                  ),
                  const SizedBox(height: 8),
                  _ShimmerBox(
                    controller: controller,
                    width: double.infinity,
                    height: 12,
                    radius: 4,
                  ),
                  const SizedBox(height: 6),
                  _ShimmerBox(
                    controller: controller,
                    width: 90,
                    height: 12,
                    radius: 4,
                  ),
                  const SizedBox(height: 6),
                  _ShimmerBox(
                    controller: controller,
                    width: 80,
                    height: 11,
                    radius: 4,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _ShimmerBox(
                        controller: controller,
                        width: 44,
                        height: 14,
                        radius: 4,
                      ),
                      const Spacer(),
                      _ShimmerBox(
                        controller: controller,
                        width: 30,
                        height: 30,
                        radius: 7,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: _ShimmerBox(
                      controller: controller,
                      width: 100,
                      height: 11,
                      radius: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    final baseColor = dark ? const Color(0xFF1E3A75) : const Color(0xFFE9ECF1);
    final highlightColor = dark
        ? const Color(0xFF2E4F92)
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
