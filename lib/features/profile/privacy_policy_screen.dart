import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFFF97315);
  static const primaryLight = Color(0xFFFFF0E6);
  static const primaryDark = Color(0xFFE05A00);

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
// SECTION DATA
// ─────────────────────────────────────────────
class _SectionData {
  final String number, title;
  final IconData icon;
  final Color color;
  final List<String> bullets;
  final String? plainBody;

  const _SectionData({
    required this.number,
    required this.title,
    required this.icon,
    required this.color,
    this.bullets = const [],
    this.plainBody,
  });
}

const _sections = [
  _SectionData(
    number: '1',
    title: 'Information We Collect',
    icon: Icons.storage_outlined,
    color: DS.primary,
    bullets: [
      'Account information: name, email, phone number, date of birth, and target exam.',
      'Learning data: courses enrolled, lessons watched, tests attempted, scores, and progress.',
      'Payment information: processed securely via PCI-compliant gateways (Razorpay in India, Stripe in UAE). We do not store full card details.',
      'Device & usage data: device type, browser, IP address, and pages visited — used to improve performance and security.',
    ],
  ),
  _SectionData(
    number: '2',
    title: 'How We Use Your Information',
    icon: Icons.visibility_outlined,
    color: DS.indigo,
    bullets: [
      'Deliver classes, tests, and personalized recommendations.',
      'Send important updates about your account, classes, and exam schedules.',
      'Provide customer support and resolve issues.',
      'Improve our platform through aggregated analytics.',
      'Comply with legal obligations in India and UAE.',
    ],
  ),
  _SectionData(
    number: '3',
    title: 'How We Protect Your Data',
    icon: Icons.lock_outline_rounded,
    color: DS.success,
    bullets: [
      'All data is encrypted in transit (TLS 1.3) and at rest (AES-256).',
      'Access is restricted on a need-to-know basis with multi-factor authentication for staff.',
      'Regular third-party security audits and vulnerability assessments.',
      'Servers hosted in compliance with Indian and UAE data residency requirements.',
    ],
  ),
  _SectionData(
    number: '4',
    title: 'Your Rights',
    icon: Icons.verified_user_outlined,
    color: DS.teal,
    bullets: [
      'Access: request a copy of all personal data we hold about you.',
      'Correction: update inaccurate information from your profile settings or by contacting us.',
      'Deletion: request permanent deletion of your account and associated data.',
      'Portability: export your learning data in a machine-readable format.',
      'Withdraw consent: opt out of marketing emails at any time via the unsubscribe link.',
    ],
  ),
  _SectionData(
    number: '5',
    title: 'Cookies & Tracking',
    icon: Icons.cookie_outlined,
    color: DS.warning,
    bullets: [
      'Essential cookies: required for login, security, and core functionality.',
      'Analytics cookies: help us understand how the platform is used (anonymized).',
      'Preference cookies: remember your region (India/Dubai), theme, and language.',
      'You can disable non-essential cookies via your browser settings.',
    ],
  ),
  _SectionData(
    number: '6',
    title: 'Sharing Your Information',
    icon: Icons.shield_outlined,
    color: DS.primary,
    bullets: [
      'We never sell your personal data to third parties.',
      'Trusted service providers (payment processors, email providers, video infrastructure) only receive the minimum data needed to perform their service.',
      'Legal disclosures: we may share data when required by law in India or UAE.',
      'Business transfers: in the event of a merger or acquisition, your data continues to be protected under this policy.',
    ],
  ),
  _SectionData(
    number: '7',
    title: 'Students Under 18',
    icon: Icons.child_care_outlined,
    color: DS.indigo,
    plainBody:
        'Many Bansal students are minors. We require verifiable parental '
        'consent for users under 18 in line with DPDPA. Parents can review, '
        'modify, or request deletion of their child\'s data at any time by '
        'writing to privacy@arke.pro.',
  ),
];

// ─────────────────────────────────────────────
// PRIVACY POLICY SCREEN
// ─────────────────────────────────────────────
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
            _PrivacyHeader(
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

                  // ── Table of contents ──
                  _TableOfContents(),
                  const SizedBox(height: DS.s24),

                  // ── Sections ──
                  ..._sections.asMap().entries.expand(
                    (e) => [
                      if (e.value.plainBody != null)
                        _PlainSection(data: e.value)
                      else
                        _BulletSection(data: e.value),
                      const SizedBox(height: DS.s16),
                    ],
                  ),

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
// PRIVACY HEADER
// ─────────────────────────────────────────────
class _PrivacyHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _PrivacyHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient bg
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8C38), DS.primary],
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

                  // Shield pill badge
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
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 13,
                        ),
                        SizedBox(width: DS.s6),
                        Text(
                          'Your privacy matters',
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
                    'Privacy Policy',
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
                    'Last updated: January 1, 2026 · This policy explains what '
                    'data Bansal collects, how we use it, and the choices you have.',
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
              Icons.info_outline_rounded,
              color: DS.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: DS.s12),
          const Expanded(
            child: Text(
              'Bansal ("we", "our", "us") operates educational services across India '
              'and the United Arab Emirates. We are committed to protecting your '
              'privacy and complying with applicable data protection laws, including '
              'India\'s Digital Personal Data Protection Act (DPDPA) 2023 and the '
              'UAE Personal Data Protection Law.',
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
// TABLE OF CONTENTS
// ─────────────────────────────────────────────
class _TableOfContents extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
          Row(
            children: const [
              Icon(Icons.list_alt_rounded, color: DS.primary, size: 16),
              SizedBox(width: DS.s8),
              Text(
                'Contents',
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
          Wrap(
            spacing: DS.s6,
            runSpacing: DS.s6,
            children: _sections
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s8,
                      vertical: DS.s4,
                    ),
                    decoration: BoxDecoration(
                      color: DS.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: DS.primary.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${s.number}. ${s.title}',
                      style: const TextStyle(
                        color: DS.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BULLET SECTION
// ─────────────────────────────────────────────
class _BulletSection extends StatelessWidget {
  final _SectionData data;
  const _BulletSection({required this.data});

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
          // Section header
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
                      color: data.color.withOpacity(0.25),
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

          const SizedBox(height: DS.s16),

          // Divider
          Divider(color: DS.border, height: 1, thickness: 1),
          const SizedBox(height: DS.s14),

          // Bullet points
          ...data.bullets.asMap().entries.map(
            (e) => Padding(
              padding: EdgeInsets.only(
                bottom: e.key < data.bullets.length - 1 ? DS.s10 : 0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: DS.s4),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: data.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: DS.textSecondary,
                        height: 1.60,
                      ),
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
// PLAIN SECTION
// ─────────────────────────────────────────────
class _PlainSection extends StatelessWidget {
  final _SectionData data;
  const _PlainSection({required this.data});

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
          // Section header
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
                      color: data.color.withOpacity(0.25),
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
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DS.s14),
          Divider(color: DS.border, height: 1, thickness: 1),
          const SizedBox(height: DS.s12),

          // Body text
          Text(
            data.plainBody!,
            style: const TextStyle(
              fontSize: 13.5,
              color: DS.textSecondary,
              height: 1.65,
            ),
          ),

          // Email pill for under-18 section
          if (data.number == '7') ...[
            const SizedBox(height: DS.s14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s12,
                vertical: DS.s8,
              ),
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                border: Border.all(
                  color: DS.primary.withOpacity(0.20),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.mail_outline_rounded, color: DS.primary, size: 14),
                  SizedBox(width: DS.s6),
                  Text(
                    'privacy@arke.pro',
                    style: TextStyle(
                      color: DS.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
          colors: [Color(0xFFFF8C38), DS.primary],
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
                  Icons.mail_outline_rounded,
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
                      'Questions about your data?',
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
                      'We\'re here to help',
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
            'Reach out to our Data Protection Officer for any privacy-related concerns.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontSize: 13,
              height: 1.55,
            ),
          ),

          const SizedBox(height: DS.s16),

          // Email pill
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
                      'privacy@arke.pro',
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
