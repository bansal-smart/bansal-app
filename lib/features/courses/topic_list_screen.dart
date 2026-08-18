import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'data/courses_providers.dart';
import 'data/models/course_topic.dart';
import '../../core/error/app_exception.dart';

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
abstract class DS {
  static const primary = Color(0xFF193F8F);
  static const primaryLight = Color(0xFFE8EDF9);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);

  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// TOPIC LIST SCREEN (Subject → Topics)
// ─────────────────────────────────────────────
class TopicListScreen extends ConsumerWidget {
  final String courseId;
  final String subjectId;
  final String subjectName;

  const TopicListScreen({
    super.key,
    required this.courseId,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(courseTopicsProvider(subjectId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            _Header(title: subjectName),
            Expanded(
              child: topicsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: DS.primary, strokeWidth: 2.5),
                ),
                error: (e, _) => _ErrorBody(message: AppException.from(e).userMessage),
                data: (topics) {
                  if (topics.isEmpty) return const _EmptyTopics();
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                        DS.s16, DS.s20, DS.s16, DS.s32),
                    itemCount: topics.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: DS.s10),
                    itemBuilder: (_, i) => _TopicTile(
                      topic: topics[i],
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push(
                          '/my-courses/$courseId/subject/$subjectId/topic/${topics[i].id}',
                          extra: topics[i].name,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
                color: Color(0x472B5BB8),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s16, DS.s20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
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
                  const SizedBox(width: DS.s12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0x2EFFFFFF),
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(
                        color: const Color(0x47FFFFFF),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(7),
                    child: SvgPicture.asset(
                      'assets/SVGs/folder-blank.svg',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Topics',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -40,
          right: -30,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TOPIC TILE
// ─────────────────────────────────────────────
class _TopicTile extends StatelessWidget {
  final CourseTopic topic;
  final VoidCallback onTap;

  const _TopicTile({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: DS.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: DS.s12),
          Expanded(
            child: Text(
              topic.name,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: DS.textSecondary, size: 20),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// EMPTY / ERROR
// ─────────────────────────────────────────────
class _EmptyTopics extends StatelessWidget {
  const _EmptyTopics();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DS.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2B5BB8), DS.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.menu_book_outlined,
                color: Colors.white, size: 32),
          ),
          const SizedBox(height: DS.s20),
          const Text(
            'No topics yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s8),
          const Text(
            'Topics will appear here once published.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DS.textSecondary, fontSize: 13.5),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DS.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: DS.errorSurface,
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: DS.error,
              size: 28,
            ),
          ),
          const SizedBox(height: DS.s12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DS.textSecondary, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}
