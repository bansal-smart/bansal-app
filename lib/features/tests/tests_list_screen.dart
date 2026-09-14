import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import '../../skeleton_loading/tests_skeleton.dart';
import 'data/tests_providers.dart';

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
  static const warningSurface = Color(0xFFFFF7ED);
  static const muted = Color(0xFF9CA3AF);
  static const mutedSurface = Color(0xFFF3F4F6);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);

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
// TESTS LIST SCREEN — mirrors web's /my-tests page
// ─────────────────────────────────────────────
class TestsListScreen extends ConsumerStatefulWidget {
  const TestsListScreen({super.key});

  @override
  ConsumerState<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends ConsumerState<TestsListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _closedGroups = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TestGroup> _filterGroups(List<TestGroup> groups) {
    if (_query.trim().isEmpty) return groups;
    final q = _query.trim().toLowerCase();
    return groups
        .map(
          (g) => TestGroup(
            key: g.key,
            label: g.label,
            tests: g.tests
                .where((t) => t.test.title.toLowerCase().contains(q))
                .toList(),
          ),
        )
        .where((g) => g.tests.isNotEmpty)
        .toList();
  }

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
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: DS.background,
          body: groupsAsync.when(
            loading: () => const TestsSkeleton(),
            error: (e, _) => _ErrorState(
              message: AppException.from(e).userMessage,
              onRetry: () => ref.invalidate(accessibleTestGroupsProvider),
            ),
            data: (groups) {
              final totalTests = groups.fold<int>(
                0,
                (s, g) => s + g.tests.length,
              );
              final filtered = _filterGroups(groups);

              return RefreshIndicator(
                color: DS.primary,
                onRefresh: () async {
                  ref.invalidate(accessibleTestGroupsProvider);
                  await ref.read(accessibleTestGroupsProvider.future);
                },
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _TestsHeader(
                        totalTests: totalTests,
                        searchCtrl: _searchCtrl,
                        onSearchChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                    if (groups.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else if (filtered.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          title: 'No matching tests',
                          subtitle: 'Try a different search term.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          DS.s16,
                          DS.s16,
                          DS.s16,
                          DS.s32,
                        ),
                        sliver: SliverList.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: DS.s14),
                          itemBuilder: (_, i) => _GroupCard(
                            group: filtered[i],
                            isOpen: !_closedGroups.contains(filtered[i].key),
                            onToggle: () => setState(() {
                              final key = filtered[i].key;
                              if (!_closedGroups.remove(key)) {
                                _closedGroups.add(key);
                              }
                            }),
                            onTapTest: _openTest,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER — solid navy, title + count + search
// ─────────────────────────────────────────────
class _TestsHeader extends StatelessWidget {
  final int totalTests;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;

  const _TestsHeader({
    required this.totalTests,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: DS.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(DS.radiusXl),
          bottomRight: Radius.circular(DS.radiusXl),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Live Tests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: DS.s4),
              Text(
                '$totalTests test${totalTests == 1 ? '' : 's'} available',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: DS.s16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 14, color: DS.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search for tests...',
                    hintStyle: const TextStyle(
                      color: DS.textHint,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: DS.textSecondary,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: DS.s12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GROUP CARD — collapsible section per course / General Practice
// ─────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final TestGroup group;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<TestWithStatus> onTapTest;

  const _GroupCard({
    required this.group,
    required this.isOpen,
    required this.onToggle,
    required this.onTapTest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(DS.s14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: DS.primaryLight,
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: DS.primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: DS.textPrimary,
                          ),
                        ),
                        Text(
                          '${group.tests.length} test${group.tests.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: DS.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: DS.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: isOpen
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const Divider(height: 1, color: DS.border),
                for (int i = 0; i < group.tests.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: DS.border),
                  _TestRow(
                    item: group.tests[i],
                    onTap: () => onTapTest(group.tests[i]),
                  ),
                ],
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEST ROW — badge line, title, meta, status pill
// ─────────────────────────────────────────────
class _TestRow extends StatelessWidget {
  final TestWithStatus item;
  final VoidCallback onTap;

  const _TestRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = item.test;
    final disabled = item.isCbtAbsent;
    final badgeParts = [
      t.testType,
      t.examPattern,
    ].where((p) => p.isNotEmpty).map((p) => p.toUpperCase()).join(' · ');
    final metaParts = <String>[
      '${t.totalQuestions} Qs',
      '${t.durationMinutes} min',
      if (t.subjects.isNotEmpty) t.subjects.join(' · '),
    ];

    return Opacity(
      opacity: disabled ? 0.7 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(DS.s14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DS.warningSurface,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: DS.warning,
                  size: 19,
                ),
              ),
              const SizedBox(width: DS.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badgeParts.isNotEmpty)
                      Text(
                        badgeParts,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: DS.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: DS.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      metaParts.join('  ·  '),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DS.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DS.s8),
              _StatusTrailing(item: item),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTrailing extends StatelessWidget {
  final TestWithStatus item;
  const _StatusTrailing({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.isCbtAbsent) {
      return const _StatusPill(
        label: 'Absent — No Result',
        fg: DS.muted,
        bg: DS.mutedSurface,
      );
    }
    if (item.isSubmitted) {
      if (item.canStartApprovedReattempt) {
        return const _StatusPill(
          label: 'Retake approved',
          fg: DS.primary,
          bg: DS.primaryLight,
        );
      }
      return const _StatusPill(
        label: 'View Result',
        fg: DS.success,
        bg: DS.successSurface,
      );
    }
    if (item.isInProgress) {
      return const _StatusPill(
        label: 'Resume',
        fg: DS.warning,
        bg: DS.warningSurface,
      );
    }
    return const Padding(
      padding: EdgeInsets.only(top: DS.s4),
      child: Icon(Icons.chevron_right_rounded, color: DS.textSecondary),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;

  const _StatusPill({required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY / LOADING / ERROR STATES
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({
    this.title = 'No tests yet',
    this.subtitle = 'Check back soon — new tests are added regularly.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DS.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: DS.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: DS.s20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: DS.error, size: 36),
            const SizedBox(height: DS.s16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DS.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: DS.s16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: DS.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
