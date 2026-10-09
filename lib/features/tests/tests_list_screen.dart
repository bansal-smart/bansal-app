import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/error/app_exception.dart';
import '../../core/theme/colors.dart';
import '../../skeleton_loading/tests_skeleton.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';
import '../profile/data/dashboard_stats_providers.dart';
import 'data/tests_providers.dart';

// ─────────────────────────────────────────────
// Design tokens (Figma)
// ─────────────────────────────────────────────
abstract class DS {
  static const ink = AppColors.ink;
  static const soft = Color(0xFF6B7280);
  static const tileBlue = Color(0xFFE6EDF8);
  static const sectionBlue = Color(0xFFE9F0FB);
  static const sectionPeach = Color(0xFFFDEEDC);
  static const rowBeige = Color(0xFFEFE5D9);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const indigo = Color(0xFF6366F1);
  static const sky = Color(0xFF0EA5E9);

  static const shadow = [
    BoxShadow(color: Color(0x1F102A5C), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

/// One "Test Type" section. Tests are bucketed by their free-text
/// `test_type`; the four types from the design always appear first.
class _TypeSection {
  final String key;
  final String label;
  final List<TestWithStatus> tests;
  _TypeSection(this.key, this.label) : tests = [];
}

const _fixedTypes = [
  ('part', 'Part Test'),
  ('review', 'Review Test'),
  ('full', 'Full Syllabus Test'),
  ('practice', 'Practice Test'),
];

String _typeKey(String testType) {
  final t = testType.toLowerCase().replaceAll(RegExp('[^a-z]'), '');
  if (t.contains('part')) return 'part';
  if (t.contains('review')) return 'review';
  if (t.contains('full') || t.contains('syllabus')) return 'full';
  if (t.contains('practice') || t.contains('dpp')) return 'practice';
  return t.isEmpty ? 'other' : t;
}

String _titleCase(String s) => s
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
    .join(' ');

List<_TypeSection> _sectionsFrom(List<TestGroup> groups) {
  final sections = <String, _TypeSection>{
    for (final (key, label) in _fixedTypes) key: _TypeSection(key, label),
  };
  for (final group in groups) {
    for (final item in group.tests) {
      final key = _typeKey(item.test.testType);
      sections
          .putIfAbsent(key, () {
            final raw = _titleCase(item.test.testType);
            final label = raw.isEmpty
                ? 'Other Tests'
                : raw.toLowerCase().endsWith('test')
                ? raw
                : '$raw Test';
            return _TypeSection(key, label);
          })
          .tests
          .add(item);
    }
  }
  return sections.values.toList();
}

// ─────────────────────────────────────────────
// TESTS LIST SCREEN
// ─────────────────────────────────────────────
class TestsListScreen extends ConsumerStatefulWidget {
  const TestsListScreen({super.key});

  @override
  ConsumerState<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends ConsumerState<TestsListScreen> {
  /// Expanded section keys; null until the first data load picks a default.
  Set<String>? _open;

  void _openTest(TestWithStatus item) {
    if (item.isCbtAbsent) return;
    HapticFeedback.selectionClick();
    if (item.isInProgress) {
      context.push('/test/${item.test.id}');
    } else if (item.canStartApprovedReattempt) {
      context.push('/test-instructions/${item.test.id}');
    } else if (item.isSubmitted) {
      context.push('/test-result/${item.attempt!.id}');
    } else {
      context.push('/test-instructions/${item.test.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(accessibleTestGroupsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: groupsAsync.when(
          loading: () => const TestsSkeleton(),
          error: (e, _) => _ErrorState(
            message: AppException.from(e).userMessage,
            onRetry: () => ref.invalidate(accessibleTestGroupsProvider),
          ),
          data: (groups) {
            final sections = _sectionsFrom(groups);
            // Open the first section that has tests, once.
            _open ??= {
              for (final s in sections)
                if (s.tests.isNotEmpty) s.key,
            }.take(1).toSet();

            final available = groups
                .expand((g) => g.tests)
                .where((t) => !t.isSubmitted && !t.isCbtAbsent)
                .length;

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(accessibleTestGroupsProvider);
                ref.invalidate(accuracyProvider);
                ref.invalidate(airPercentileProvider);
                await ref.read(accessibleTestGroupsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  const Text(
                    'My Test',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: DS.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _TestsHero(available: available),
                  const SizedBox(height: 28),
                  const Text(
                    'TEST TYPE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: DS.ink,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(height: 14),
                    _TypeCard(
                      number: i + 1,
                      section: sections[i],
                      isOpen: _open!.contains(sections[i].key),
                      onToggle: () => setState(() {
                        final key = sections[i].key;
                        if (!_open!.remove(key)) _open!.add(key);
                      }),
                      onTapTest: _openTest,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO — course pill, greeting and three stats
// ─────────────────────────────────────────────
class _TestsHero extends ConsumerWidget {
  final int available;
  const _TestsHero({required this.available});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollments =
        ref.watch(enrollmentsProvider).valueOrNull ?? const <Enrollment>[];
    final recent = enrollments.isEmpty
        ? null
        : ([...enrollments]..sort((a, b) {
                final aT = a.lastAccessedAt ?? a.createdAt;
                final bT = b.lastAccessedAt ?? b.createdAt;
                return bT.compareTo(aT);
              }))
              .first;
    final accuracy = ref.watch(accuracyProvider).valueOrNull;
    final percentile = ref.watch(airPercentileProvider).valueOrNull;
    final meta = [
      recent?.courseSubject,
      recent?.courseEducatorName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33102A5C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The course block takes all the width "All The Best!" leaves,
              // so long course names wrap at word boundaries instead of
              // being squeezed mid-word.
              Expanded(
                child: recent == null
                    ? const SizedBox.shrink()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              recent.courseTitle ?? 'My Course',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (meta.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                meta,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.3,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  'All The Best!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  icon: LucideIcons.clipboardCheck,
                  color: DS.indigo,
                  value: '$available',
                  label: 'Available Test',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  icon: LucideIcons.target,
                  color: DS.success,
                  value: accuracy == null ? '—' : '$accuracy%',
                  label: 'Accuracy',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroStat(
                  icon: LucideIcons.chartColumn,
                  color: DS.sky,
                  value: percentile == null
                      ? '—'
                      : '${percentile.toStringAsFixed(percentile % 1 == 0 ? 0 : 1)}%',
                  label: 'Percentile',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _HeroStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: DS.tileBlue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 16, color: color),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
                color: DS.ink,
              ),
            ),
          ),
          // Scales down on narrow phones rather than cutting the label off.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 10, color: DS.soft),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEST TYPE CARD — numbered, expandable
// ─────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final int number;
  final _TypeSection section;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<TestWithStatus> onTapTest;

  const _TypeCard({
    required this.number,
    required this.section,
    required this.isOpen,
    required this.onToggle,
    required this.onTapTest,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isOpen ? DS.sectionPeach : DS.sectionBlue,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: DS.shadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: isOpen,
            label: '${section.label}, ${section.tests.length} tests',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 18, 8),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x29000000),
                            blurRadius: 5,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: DS.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        section.label.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: DS.ink,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Icon(
                      isOpen
                          ? LucideIcons.chevronDown200
                          : LucideIcons.chevronRight200,
                      size: 26,
                      color: DS.soft,
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !isOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                    child: section.tests.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              'No tests here yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: DS.soft),
                            ),
                          )
                        : Column(
                            children: [
                              for (
                                var i = 0;
                                i < section.tests.length;
                                i++
                              ) ...[
                                if (i > 0) const SizedBox(height: 12),
                                _TestRow(
                                  item: section.tests[i],
                                  onTap: () => onTapTest(section.tests[i]),
                                ),
                              ],
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
// TEST ROW
// ─────────────────────────────────────────────
class _TestRow extends StatelessWidget {
  final TestWithStatus item;
  final VoidCallback onTap;

  const _TestRow({required this.item, required this.onTap});

  static const _short = {
    'physics': 'PHY',
    'chemistry': 'CHEM',
    'mathematics': 'MATHS',
    'maths': 'MATHS',
    'math': 'MATHS',
    'biology': 'BIO',
    'botany': 'BOT',
    'zoology': 'ZOO',
  };

  @override
  Widget build(BuildContext context) {
    final t = item.test;
    final disabled = item.isCbtAbsent;
    final subjectTag = t.subjects.length == 1
        ? (_short[t.subjects.first.trim().toLowerCase()] ??
              t.subjects.first.toUpperCase())
        : null;
    final meta = [
      '${t.totalQuestions} Qs',
      '${t.durationMinutes} min',
      if (t.examPattern.isNotEmpty) t.examPattern.toUpperCase(),
    ].join(' • ');

    final (status, statusColor) = item.isCbtAbsent
        ? ('ABSENT', DS.soft)
        : item.canStartApprovedReattempt
        ? ('RETAKE', AppColors.primary)
        : item.isSubmitted
        ? ('RESULT', DS.success)
        : item.isInProgress
        ? ('RESUME', DS.warning)
        : ('START', DS.soft);

    // Geometry mirrors the section header above: a 44px leading slot centred
    // under the number circle, then a 20px gap, so the test title starts at
    // exactly the same x as the "PART TEST" label.
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Material(
          color: DS.rowBeige,
          borderRadius: BorderRadius.circular(10),
          elevation: 1.5,
          shadowColor: const Color(0x55000000),
          child: InkWell(
            onTap: disabled ? null : onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 10, 10),
              child: Row(
                children: [
                  const SizedBox(
                    width: 44,
                    child: Icon(LucideIcons.fileText, size: 18, color: DS.soft),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subjectTag == null
                              ? t.title
                              : '$subjectTag • ${t.title}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                            color: DS.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            height: 1.3,
                            color: DS.soft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: DS.soft,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: DS.shadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleAlert, color: DS.error, size: 34),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DS.soft, fontSize: 13.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
