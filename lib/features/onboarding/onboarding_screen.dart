import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';

// ── Slide data ─────────────────────────────────────────────────────────────
class _Slide {
  final String image;
  final String examLabel;
  final Color examColor;
  final String headline;
  final String description;
  final String tagline;
  final Color accentColor;
  final Color bgColor;

  const _Slide({
    required this.image,
    required this.examLabel,
    required this.examColor,
    required this.headline,
    required this.description,
    required this.tagline,
    required this.accentColor,
    required this.bgColor,
  });
}

const _kSlides = [
  _Slide(
    image: 'assets/images/jee.png',
    examLabel: 'JEE',
    examColor: Color(0xFF193F8F),
    headline: 'Crack the Exam.\nBuild the Future.',
    description: 'Top-notch preparation for JEE\nMain & Advanced.',
    tagline: 'Your dream rank is a step away!',
    accentColor: Color(0xFF193F8F),
    bgColor: Color(0xFFFFF7F0),
  ),
  _Slide(
    image: 'assets/images/neet.jpeg',
    examLabel: 'NEET',
    examColor: Color(0xFF16A34A),
    headline: 'Dream. Prepare.\nBecome a Healer.',
    description: 'Comprehensive NEET preparation\nfor your medical career.',
    tagline: 'Every step today, heals tomorrow.',
    accentColor: Color(0xFF16A34A),
    bgColor: Color(0xFFF0FDF4),
  ),
  _Slide(
    image: 'assets/images/boards.png',
    examLabel: 'BOARD',
    examColor: Color(0xFF2563EB),
    headline: 'Strong Concepts.\nBright Results.',
    description:
        'Excel in your board exams with\nconcept clarity and practice.',
    tagline: 'Strong basics. Endless possibilities.',
    accentColor: Color(0xFF2563EB),
    bgColor: Color(0xFFEFF6FF),
  ),
  _Slide(
    image: 'assets/images/foundation.png',
    examLabel: 'FOUNDATION',
    examColor: Color(0xFF193F8F),
    headline: 'Strong Foundation.\nLimitless Future.',
    description: 'Build a strong base for JEE, NEET\nand beyond.',
    tagline: 'A strong start builds a strong future.',
    accentColor: Color(0xFF193F8F),
    bgColor: Color(0xFFFFF7F0),
  ),
];

// ── Screen ─────────────────────────────────────────────────────────────────
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(prefsProvider).setOnboardingDone(true);
    if (mounted) context.go('/login');
  }

  void _next() {
    // Use controller's actual page to avoid stale _page state during animation
    final currentPage =
        (_pageCtrl.hasClients ? _pageCtrl.page?.round() : null) ?? _page;
    if (currentPage < _kSlides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _kSlides[_page];
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final topPad = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            // ── Top section: exam label + headline + description ───────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              color: slide.bgColor,
              padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Skip button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_page < _kSlides.length - 1)
                        GestureDetector(
                          onTap: _finish,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Exam label — fixed height so all slides stay consistent
                  SizedBox(
                    height: 44,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          slide.examLabel,
                          key: ValueKey(slide.examLabel),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: slide.examColor,
                            letterSpacing: 1.5,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Headline
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      slide.headline,
                      key: ValueKey(slide.headline),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Description
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      slide.description,
                      key: ValueKey(slide.description),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF6B7280),
                        height: 1.55,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // ── Image carousel ─────────────────────────────────────────────
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                color: slide.bgColor,
                child: PageView.builder(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _kSlides.length,
                  itemBuilder: (_, i) => _SlidePage(slide: _kSlides[i]),
                ),
              ),
            ),

            // ── Bottom controls ────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _kSlides.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? slide.accentColor
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: slide.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ((_pageCtrl.hasClients
                                            ? _pageCtrl.page?.round()
                                            : null) ??
                                        _page) ==
                                    _kSlides.length - 1
                                ? 'Get Started'
                                : 'Start Learning',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tagline
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      slide.tagline,
                      key: ValueKey(slide.tagline),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF9CA3AF),
                        fontStyle: FontStyle.italic,
                      ),
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

// ── Single slide image ─────────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          slide.image,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
    );
  }
}
