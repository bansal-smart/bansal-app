import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/landing_hero_banner.dart';

class LandingBannerCarousel extends StatefulWidget {
  const LandingBannerCarousel({
    required this.banners,
    super.key,
    this.autoAdvanceDuration = const Duration(milliseconds: 4500),
  });

  final List<LandingHeroBanner> banners;
  final Duration autoAdvanceDuration;

  @override
  State<LandingBannerCarousel> createState() =>
      _LandingBannerCarouselState();
}

class _LandingBannerCarouselState extends State<LandingBannerCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LandingBannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.banners.length != oldWidget.banners.length ||
        widget.autoAdvanceDuration != oldWidget.autoAdvanceDuration) {
      if (_currentIndex >= widget.banners.length) {
        _currentIndex = 0;
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      }
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.banners.length <= 1) return;
    _timer = Timer.periodic(widget.autoAdvanceDuration, (_) {
      if (!mounted || !_pageController.hasClients) return;
      final next = (_currentIndex + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    _startTimer();
  }

  Future<void> _openLink(String? value) async {
    final link = value?.trim();
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final showControls = widget.banners.length > 1;
    return AspectRatio(
      aspectRatio: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: const Color(0xFFE8EDF9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                label: 'Promotional banners',
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.banners.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final banner = widget.banners[index];
                    final hasLink = banner.link?.trim().isNotEmpty == true;
                    return Semantics(
                      button: hasLink,
                      label: banner.alt?.trim().isNotEmpty == true
                          ? banner.alt!.trim()
                          : 'Bansal Classes banner ${index + 1}',
                      child: GestureDetector(
                        onTap: hasLink ? () => _openLink(banner.link) : null,
                        child: CachedNetworkImage(
                          imageUrl: banner.imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, _) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (_, _, _) => const Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (showControls) ...[
                _CarouselArrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left_rounded,
                  semanticLabel: 'Previous banner',
                  onPressed: () => _goToPage(
                    (_currentIndex - 1 + widget.banners.length) %
                        widget.banners.length,
                  ),
                ),
                _CarouselArrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'Next banner',
                  onPressed: () => _goToPage(
                    (_currentIndex + 1) % widget.banners.length,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.banners.length, (index) {
                        final selected = index == _currentIndex;
                        return Semantics(
                          button: true,
                          label: 'Show banner ${index + 1}',
                          selected: selected,
                          child: GestureDetector(
                            onTap: () => _goToPage(index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: selected ? 22 : 7,
                              height: 7,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFFF6500)
                                    : Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(99),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  const _CarouselArrow({
    required this.alignment,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final Alignment alignment;
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox.square(
          dimension: 34,
          child: IconButton(
            tooltip: semanticLabel,
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.9),
              foregroundColor: const Color(0xFFFF6500),
            ),
            icon: Icon(icon, size: 23),
          ),
        ),
      ),
    );
  }
}
