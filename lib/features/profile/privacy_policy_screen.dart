import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryMid = Color(0xFF2B5BB8);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFF6F7FB);
  static const surface = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  // Soft, layered card shadow — replaces hard 1.2px borders.
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: DS.primaryDark.withValues(alpha: 0.06),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: DS.primaryDark.withValues(alpha: 0.03),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];
}

// ─────────────────────────────────────────────
// PRIVACY POLICY SCREEN — fetched live from the same site_pages table
// (slug='privacy') the web app renders, so both platforms always match.
// ─────────────────────────────────────────────
class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  static const double _headerHeight = 236;

  final ScrollController _scroll = ScrollController();
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final ValueNotifier<bool> _showTopButton = ValueNotifier<bool>(false);

  bool _loading = true;
  String? _error;
  String _title = 'Privacy Policy';
  String _contentHtml = '';
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _progress.dispose();
    _showTopButton.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _progress.value = max <= 0 ? 0 : (_scroll.offset / max).clamp(0.0, 1.0);
    _showTopButton.value = _scroll.offset > 320;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await SupabaseService.client
          .from('site_pages')
          .select('title, content_html, updated_at')
          .eq('slug', 'privacy')
          .maybeSingle();

      if (row == null) {
        setState(() {
          _error = 'This page is not available right now.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _title = row['title'] as String? ?? 'Privacy Policy';
        _contentHtml = row['content_html'] as String? ?? '';
        _updatedAt = row['updated_at'] != null
            ? DateTime.tryParse(row['updated_at'] as String)
            : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppException.from(e).userMessage;
        _loading = false;
      });
    }
  }

  void _back() {
    HapticFeedback.selectionClick();
    context.canPop() ? context.pop() : context.go('/settings');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        floatingActionButton: _BackToTopButton(
          visible: _showTopButton,
          onTap: () {
            HapticFeedback.selectionClick();
            _scroll.animateTo(
              0,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
            );
          },
        ),
        body: RefreshIndicator(
          color: DS.primary,
          backgroundColor: DS.surface,
          displacement: _headerHeight * 0.5,
          onRefresh: _load,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _PrivacyHeader(
                title: _title,
                updatedAt: _updatedAt,
                expandedHeight: _headerHeight,
                progress: _progress,
                onBack: _back,
              ),
              if (_loading)
                const SliverToBoxAdapter(child: _LoadingSkeleton())
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(message: _error!, onRetry: _load),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    DS.s16,
                    DS.s20,
                    DS.s16,
                    DS.s12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _ContentCard(html: _contentHtml),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(DS.s16, 0, DS.s16, DS.s32),
                  sliver: const SliverToBoxAdapter(child: _FooterNote()),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER — collapses to a compact bar, carries a reading-progress rail
// ─────────────────────────────────────────────
class _PrivacyHeader extends StatelessWidget {
  final String title;
  final DateTime? updatedAt;
  final double expandedHeight;
  final ValueNotifier<double> progress;
  final VoidCallback onBack;

  const _PrivacyHeader({
    required this.title,
    required this.updatedAt,
    required this.expandedHeight,
    required this.progress,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final minHeight = kToolbarHeight + topPad;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: expandedHeight,
      backgroundColor: DS.primary,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(DS.radiusXl),
        ),
      ),
      leadingWidth: 60,
      leading: Padding(
        padding: const EdgeInsets.only(left: DS.s16),
        child: _GlassIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: onBack,
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final range = (expandedHeight - minHeight).clamp(1.0, 9999.0);
          final t = ((constraints.maxHeight - minHeight) / range).clamp(
            0.0,
            1.0,
          );

          return ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(DS.radiusXl),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base gradient
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [DS.primaryMid, DS.primary, DS.primaryDark],
                      stops: [0, 0.55, 1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                // Ambient light shapes
                Positioned(
                  top: -70,
                  right: -50,
                  child: _Blob(size: 200, opacity: 0.08 * t),
                ),
                Positioned(
                  top: 30,
                  right: 34,
                  child: _Blob(size: 56, opacity: 0.10 * t),
                ),
                Positioned(
                  bottom: -50,
                  left: -30,
                  child: _Blob(size: 140, opacity: 0.05 * t),
                ),

                // Compact (collapsed) title
                Positioned(
                  top: topPad,
                  left: 60,
                  right: DS.s16,
                  height: kToolbarHeight,
                  child: Opacity(
                    opacity: (1 - t * 2.2).clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),

                // Expanded content
                Positioned(
                  left: DS.s20,
                  right: DS.s20,
                  bottom: DS.s24,
                  child: Opacity(
                    opacity: ((t - 0.25) / 0.75).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _Pill(
                            icon: Icons.verified_user_rounded,
                            label: 'Legal',
                          ),
                          const SizedBox(height: DS.s12),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: DS.s8),
                          Text(
                            updatedAt != null
                                ? 'Updated ${DateFormat('d MMMM y').format(updatedAt!.toLocal())}'
                                : 'How Bansal Classes collects, uses and protects your data.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.80),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(3),
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, value, _) => Container(
            height: 3,
            color: Colors.white.withValues(alpha: 0.14),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value == 0 ? 0.001 : value,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.horizontal(
                    right: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: DS.s6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(DS.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(DS.radiusSm),
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTENT CARD
// ─────────────────────────────────────────────
class _ContentCard extends StatelessWidget {
  final String html;
  const _ContentCard({required this.html});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(DS.s20, DS.s20, DS.s20, DS.s24),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: DS.cardShadow,
      ),
      child: Html(
        data: html,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            fontSize: FontSize(14),
            color: DS.textSecondary,
            lineHeight: LineHeight(1.72),
            fontWeight: FontWeight.w400,
          ),
          'p': Style(margin: Margins.only(bottom: 14)),
          'h1': Style(
            margin: Margins.only(top: 4, bottom: 12),
            fontSize: FontSize(21),
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: DS.textPrimary,
          ),
          'h2': Style(
            margin: Margins.only(top: 24, bottom: 10),
            fontSize: FontSize(17.5),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: DS.textPrimary,
            lineHeight: LineHeight(1.3),
          ),
          'h3': Style(
            margin: Margins.only(top: 18, bottom: 6),
            fontSize: FontSize(15),
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
          ),
          'ul': Style(margin: Margins.only(bottom: 14, left: 2)),
          'ol': Style(margin: Margins.only(bottom: 14, left: 2)),
          'li': Style(margin: Margins.only(bottom: 8)),
          'strong': Style(fontWeight: FontWeight.w800, color: DS.textPrimary),
          'em': Style(fontStyle: FontStyle.italic),
          'a': Style(
            color: DS.primary,
            fontWeight: FontWeight.w700,
            textDecoration: TextDecoration.none,
          ),
          'blockquote': Style(
            margin: Margins.only(bottom: 14),
            padding: HtmlPaddings.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: DS.primaryLight,
            border: const Border(left: BorderSide(color: DS.primary, width: 3)),
            color: DS.textPrimary,
          ),
          'hr': Style(
            margin: Margins.symmetric(vertical: 20),
            border: const Border(
              bottom: BorderSide(color: DS.border, width: 1),
            ),
          ),
          'table': Style(margin: Margins.only(bottom: 14)),
          'th': Style(
            padding: HtmlPaddings.all(8),
            backgroundColor: DS.primaryLight,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
          ),
          'td': Style(padding: HtmlPaddings.all(8)),
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FOOTER NOTE
// ─────────────────────────────────────────────
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.primaryLight,
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DS.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: DS.primary,
              size: 17,
            ),
          ),
          const SizedBox(width: DS.s12),
          const Expanded(
            child: Text(
              'This policy applies to the Bansal Classes app and website. '
              'Pull down to refresh for the latest version.',
              style: TextStyle(
                color: DS.primaryDark,
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOADING SKELETON (shimmer, no extra package)
// ─────────────────────────────────────────────
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s20, DS.s16, DS.s32),
      child: Container(
        padding: const EdgeInsets.all(DS.s20),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          boxShadow: DS.cardShadow,
        ),
        child: const _Shimmer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Bar(width: 170, height: 18),
              SizedBox(height: DS.s16),
              _Bar(height: 11),
              SizedBox(height: DS.s10),
              _Bar(height: 11),
              SizedBox(height: DS.s10),
              _Bar(width: 240, height: 11),
              SizedBox(height: DS.s24),
              _Bar(width: 140, height: 15),
              SizedBox(height: DS.s16),
              _Bar(height: 11),
              SizedBox(height: DS.s10),
              _Bar(height: 11),
              SizedBox(height: DS.s10),
              _Bar(width: 200, height: 11),
              SizedBox(height: DS.s24),
              _Bar(width: 155, height: 15),
              SizedBox(height: DS.s16),
              _Bar(height: 11),
              SizedBox(height: DS.s10),
              _Bar(width: 180, height: 11),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double? width;
  final double height;
  const _Bar({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: DS.border,
        borderRadius: BorderRadius.circular(DS.s6),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Respect reduced-motion: show a static skeleton instead of a sweep.
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (_c.value * 2.4 - 0.7);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0xCCFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double dx;
  const _SlideGradient(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(DS.s32, DS.s32, DS.s32, DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: DS.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_tethering_off_rounded,
                color: DS.error,
                size: 30,
              ),
            ),
            const SizedBox(height: DS.s20),
            const Text(
              'Could not load this page',
              style: TextStyle(
                color: DS.textPrimary,
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
            const SizedBox(height: DS.s24),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DS.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: DS.s24),
                  textStyle: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BACK TO TOP
// ─────────────────────────────────────────────
class _BackToTopButton extends StatelessWidget {
  final ValueNotifier<bool> visible;
  final VoidCallback onTap;

  const _BackToTopButton({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, show, child) => AnimatedSlide(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        offset: show ? Offset.zero : const Offset(0, 1.6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: show ? 1 : 0,
          child: IgnorePointer(ignoring: !show, child: child),
        ),
      ),
      child: FloatingActionButton.small(
        onPressed: onTap,
        backgroundColor: DS.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        tooltip: 'Back to top',
        child: const Icon(Icons.arrow_upward_rounded, size: 18),
      ),
    );
  }
}
