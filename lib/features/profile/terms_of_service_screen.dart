import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);
  static const primaryDark = Color(0xFF102A63);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);
  static const teal = Color(0xFF14B8A6);
  static const purple = Color(0xFF8B5CF6);

  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// SECTION DATA MODEL
// ─────────────────────────────────────────────
class _SectionData {
  final String number, title;
  final IconData icon;
  final Color color;
  final String body;

  const _SectionData({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    required this.body,
  });
}

const _sections = [
  _SectionData(
    number: '1',
    title: 'Acceptance of Terms',
    icon: Icons.description_outlined,
    color: DS.primary,
    body:
        'By creating an account or using Bansal, you agree to be bound by these '
        'Terms of Service. If you do not agree, please do not use the platform. '
        'Users under 18 must have parental or guardian consent.',
  ),
  _SectionData(
    number: '2',
    title: 'Use of the Platform',
    icon: Icons.balance_outlined,
    color: DS.indigo,
    body:
        'Bansal is provided for personal, non-commercial educational use. You '
        'agree to use the platform lawfully, respect other users and educators, '
        'and not misuse content (e.g., redistribution, scraping, or unauthorized '
        'recording of live classes).',
  ),
  _SectionData(
    number: '3',
    title: 'Payments & Subscriptions',
    icon: Icons.credit_card_outlined,
    color: DS.success,
    body:
        'Subscription fees are billed in advance based on your selected plan '
        'and region (INR for India, AED for UAE). All prices are inclusive of '
        'applicable taxes. Auto-renewal applies unless cancelled at least 48 hours '
        'before the next billing cycle from your account settings.',
  ),
  _SectionData(
    number: '4',
    title: 'Refund Policy',
    icon: Icons.refresh_rounded,
    color: DS.teal,
    body:
        'We offer a 7-day money-back guarantee on all paid plans, no questions '
        'asked. After 7 days, refunds may be considered case-by-case for verified '
        'service issues. Refunds are processed to the original payment method '
        'within 7–10 business days.',
  ),
  _SectionData(
    number: '5',
    title: 'Account Termination',
    icon: Icons.block_outlined,
    color: DS.error,
    body:
        'We reserve the right to suspend or terminate accounts that violate '
        'these terms — including academic dishonesty, abusive behavior toward '
        'staff or students, content piracy, or fraudulent payment activity. '
        'You may delete your account at any time from your settings page.',
  ),
  _SectionData(
    number: '6',
    title: 'Intellectual Property',
    icon: Icons.copyright_outlined,
    color: DS.purple,
    body:
        'All course content, recordings, study materials, tests, and software '
        'on Bansal are the intellectual property of Bansal or its licensed educators. '
        'Sharing, reselling, or republishing this content without written '
        'permission is strictly prohibited and may result in legal action.',
  ),
  _SectionData(
    number: '7',
    title: 'Limitation of Liability',
    icon: Icons.gavel_outlined,
    color: DS.warning,
    body:
        'Bansal provides educational guidance and resources but cannot guarantee '
        'specific exam outcomes or admissions. To the maximum extent permitted by '
        'law, Bansal\'s total liability is limited to the amount you paid in the '
        '12 months preceding the claim. We are not liable for indirect, '
        'incidental, or consequential damages.',
  ),
  _SectionData(
    number: '8',
    title: 'Changes to These Terms',
    icon: Icons.update_rounded,
    color: DS.indigo,
    body:
        'We may update these Terms occasionally. Material changes will be '
        'communicated via email or in-app notification at least 14 days before '
        'they take effect. Continued use after that date constitutes acceptance '
        'of the updated Terms.',
  ),
  _SectionData(
    number: '9',
    title: 'Governing Law',
    icon: Icons.account_balance_outlined,
    color: DS.teal,
    body:
        'For users in India, these Terms are governed by the laws of India '
        'and disputes fall under the exclusive jurisdiction of courts in New '
        'Delhi. For users in the UAE, these Terms are governed by UAE law with '
        'jurisdiction in Dubai courts.',
  ),
];

// ─────────────────────────────────────────────
// TERMS OF SERVICE SCREEN
// ─────────────────────────────────────────────
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Orange hero header ──
            _TermsHeader(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/settings'),
            ),

            // ── Scrollable content ──
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DS.s16,
                  DS.s20,
                  DS.s16,
                  DS.s32,
                ),
                children: [
                  // ── Intro card ──
                  _IntroCard(),
                  const SizedBox(height: DS.s16),

                  // ── Key highlights ──
                  _KeyHighlightsCard(),
                  const SizedBox(height: DS.s24),

                  // ── Sections ──
                  ..._sections.asMap().entries.expand(
                    (e) => [
                      _TermsSection(data: e.value),
                      const SizedBox(height: DS.s14),
                    ],
                  ),

                  const SizedBox(height: DS.s10),

                  // ── Contact card ──
                  const _ContactCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TERMS HEADER
// ─────────────────────────────────────────────
class _TermsHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _TermsHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient bg — orange (consistent with ALL screens)
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2B5BB8), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(DS.radiusXl),
              bottomRight: Radius.circular(DS.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x47F97315),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s16, DS.s28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: DS.s20),

                  // Balance pill badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s12,
                      vertical: DS.s6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.balance_outlined,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: DS.s6),
                        Text(
                          'Fair, transparent terms',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: DS.s12),

                  // Title
                  const Text(
                    'Terms of Service',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: DS.s8),

                  // Subtitle
                  Text(
                    'Last updated: January 1, 2026 · Please read these terms '
                    'carefully before using Bansal.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 15,
          right: 20,
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// INTRO CARD
// ─────────────────────────────────────────────
class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: DS.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: DS.s12),
          const Expanded(
            child: Text(
              'These Terms of Service ("Terms") govern your access to and use of '
              'Bansal\'s website, mobile application, and services (collectively, '
              'the "Platform"). By using Bansal, you enter into a binding agreement '
              'with Bansal EdTech Pvt. Ltd. (India) and Bansal Education FZ-LLC (UAE), '
              'depending on your region.',
              style: TextStyle(
                fontSize: 13.5,
                color: DS.textSecondary,
                height: 1.65,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// KEY HIGHLIGHTS CARD (quick summary)
// ─────────────────────────────────────────────
class _KeyHighlightsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const highlights = [
      (
        Icons.check_circle_outline_rounded,
        DS.success,
        '7-day money-back guarantee',
      ),
      (Icons.block_outlined, DS.error, 'No content piracy or sharing'),
      (Icons.credit_card_outlined, DS.indigo, 'Auto-renewal — cancel anytime'),
      (Icons.gavel_outlined, DS.warning, 'India & UAE jurisdiction'),
    ];

    return Container(
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.primaryLight,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.primary.withOpacity(0.20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: const [
              Icon(Icons.flash_on_rounded, color: DS.primary, size: 16),
              SizedBox(width: DS.s8),
              Text(
                'Key Highlights',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: DS.primary,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s12),

          // Highlight rows
          ...highlights.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: DS.s8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: DS.surface,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(
                        color: h.$2.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    child: Icon(h.$1, size: 14, color: h.$2),
                  ),
                  const SizedBox(width: DS.s10),
                  Text(
                    h.$3,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: DS.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TERMS SECTION (unified for all sections)
// ─────────────────────────────────────────────
class _TermsSection extends StatelessWidget {
  final _SectionData data;
  const _TermsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s16),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with colored icon
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [data.color.withOpacity(0.70), data.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  boxShadow: [
                    BoxShadow(
                      color: data.color.withOpacity(0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(data.icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: DS.s12),
              Expanded(
                child: Text(
                  '${data.number}. ${data.title}',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: DS.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DS.s12),

          // Divider
          Divider(color: DS.border, height: 1, thickness: 1),
          const SizedBox(height: DS.s12),

          // Body text
          Text(
            data.body,
            style: const TextStyle(
              fontSize: 13.5,
              color: DS.textSecondary,
              height: 1.65,
            ),
          ),

          // Special callout for refund (section 4)
          if (data.number == '4') ...[
            const SizedBox(height: DS.s12),
            Container(
              padding: const EdgeInsets.all(DS.s12),
              decoration: BoxDecoration(
                color: DS.successSurface,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                border: Border.all(
                  color: DS.success.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.verified_outlined, color: DS.success, size: 16),
                  SizedBox(width: DS.s8),
                  Expanded(
                    child: Text(
                      '7-day money-back — no questions asked.',
                      style: TextStyle(
                        color: DS.success,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Special callout for IP (section 6)
          if (data.number == '6') ...[
            const SizedBox(height: DS.s12),
            Container(
              padding: const EdgeInsets.all(DS.s12),
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                border: Border.all(color: DS.error.withOpacity(0.25), width: 1),
              ),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: DS.error, size: 16),
                  SizedBox(width: DS.s8),
                  Expanded(
                    child: Text(
                      'Unauthorized distribution may result in legal action.',
                      style: TextStyle(
                        color: DS.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Special callout for governing law (section 9) — jurisdiction badges
          if (data.number == '9') ...[
            const SizedBox(height: DS.s14),
            Row(
              children: [
                _JurisdictionBadge(
                  flag: '🇮🇳',
                  label: 'India',
                  sub: 'New Delhi courts',
                ),
                const SizedBox(width: DS.s8),
                _JurisdictionBadge(
                  flag: '🇦🇪',
                  label: 'UAE',
                  sub: 'Dubai courts',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _JurisdictionBadge extends StatelessWidget {
  final String flag, label, sub;
  const _JurisdictionBadge({
    required this.flag,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(DS.s10),
        decoration: BoxDecoration(
          color: DS.surfaceVariant,
          borderRadius: BorderRadius.circular(DS.radiusSm),
          border: Border.all(color: DS.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: DS.s4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 11.5, color: DS.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTACT CARD
// ─────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2B5BB8), DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: [
          BoxShadow(
            color: DS.primary.withOpacity(0.32),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: DS.s14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Questions about these terms?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: DS.s4),
                    Text(
                      'Our legal team is here to help',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: DS.s14),
          Divider(color: Colors.white.withOpacity(0.20), height: 1),
          const SizedBox(height: DS.s14),

          Text(
            'Our legal team is happy to clarify anything that\'s unclear. '
            'We aim to respond within 2 business days.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 13,
              height: 1.55,
            ),
          ),

          const SizedBox(height: DS.s16),

          // Email + button row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s16,
                  vertical: DS.s10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.alternate_email_rounded,
                      color: DS.primary,
                      size: 14,
                    ),
                    SizedBox(width: DS.s6),
                    Text(
                      'legal@arke.pro',
                      style: TextStyle(
                        color: DS.primary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DS.s10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s12,
                  vertical: DS.s10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.28),
                    width: 1,
                  ),
                ),
                child: const Text(
                  'Get in touch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
