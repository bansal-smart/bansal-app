import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'data/courses_providers.dart';
import 'data/models/chapter.dart';
import 'data/models/lesson.dart';
import 'data/models/subtopic_pdf.dart';
import 'pdf_viewer_screen.dart';

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
  static const teal = Color(0xFF14B8A6);
  static const tealLight = Color(0xFFF0FDFA);

  static const double s2 = 2;
  static const double s3 = 3;
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
// COURSE PLAYER SCREEN
// ─────────────────────────────────────────────
class CoursePlayerScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String? initialLessonId;

  const CoursePlayerScreen({
    super.key,
    required this.courseId,
    this.initialLessonId,
  });

  @override
  ConsumerState<CoursePlayerScreen> createState() => _CoursePlayerScreenState();
}

class _CoursePlayerScreenState extends ConsumerState<CoursePlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  String? _activeLessonId;
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _videoReady = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _activeLessonId = widget.initialLessonId;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _chewieCtrl = null;
    _videoCtrl = null;
  }

  Future<void> _saveLessonProgress(Lesson lesson) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client.from('lesson_progress').upsert({
        'user_id': userId,
        'lesson_id': lesson.id,
        'course_id': lesson.courseId,
        'lesson_title': lesson.title,
        'last_watched_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,lesson_id');
    } catch (_) {}
  }

  Future<void> _playLesson(Lesson lesson) async {
    if (_activeLessonId == lesson.id && _videoReady) return;

    setState(() {
      _activeLessonId = lesson.id;
      _videoReady = false;
      _videoError = null;
    });
    _disposeVideo();

    final rawUrl = lesson.videoUrl;
    if (rawUrl == null || rawUrl.isEmpty) {
      setState(() => _videoError = 'not_available');
      return;
    }

    final String? url = await resolveVideoUrl(rawUrl);
    if (!mounted) return;
    if (url == null) {
      setState(() => _videoError = 'not_available');
      return;
    }

    try {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await _videoCtrl!.initialize();
      _chewieCtrl = ChewieController(
        videoPlayerController: _videoCtrl!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: DS.primary,
          handleColor: DS.primary,
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
      );
      if (mounted) {
        setState(() => _videoReady = true);
        _saveLessonProgress(lesson);
      }
    } catch (e) {
      if (mounted) setState(() => _videoError = 'not_available');
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));
    final chaptersAsync = ref.watch(chaptersProvider(widget.courseId));
    final lessonsAsync = ref.watch(lessonsProvider(widget.courseId));
    final pdfsAsync = ref.watch(coursePdfsProvider(widget.courseId));

    // Auto-play first / initial lesson
    lessonsAsync.whenData((lessons) {
      if (_activeLessonId == null && lessons.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _playLesson(lessons.first);
        });
      } else if (_activeLessonId != null &&
          !_videoReady &&
          _videoError == null &&
          _videoCtrl == null) {
        final lesson = lessons.firstWhere(
          (l) => l.id == _activeLessonId,
          orElse: () => lessons.first,
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _playLesson(lesson),
        );
      }
    });

    final courseTitle = courseAsync.valueOrNull?.name ?? 'Course';
    final activeLesson = lessonsAsync.valueOrNull
        ?.where((l) => l.id == _activeLessonId)
        .firstOrNull;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              // ── Video player ──
              _VideoSection(
                chewieCtrl: _chewieCtrl,
                videoReady: _videoReady,
                error: _videoError,
                lessonTitle: activeLesson?.title ?? courseTitle,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
              ),

              // ── Tab bar ──
              _PlayerTabBar(tabCtrl: _tabCtrl),

              // ── Tab content ──
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _LessonsTab(
                      chaptersAsync: chaptersAsync,
                      lessonsAsync: lessonsAsync,
                      activeLessonId: _activeLessonId,
                      onLessonTap: _playLesson,
                    ),
                    _PdfsTab(pdfsAsync: pdfsAsync, courseId: widget.courseId),
                    _InfoTab(courseAsync: courseAsync),
                  ],
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
// VIDEO SECTION
// ─────────────────────────────────────────────
class _VideoSection extends StatelessWidget {
  final ChewieController? chewieCtrl;
  final bool videoReady;
  final String? error;
  final String lessonTitle;
  final VoidCallback onBack;

  const _VideoSection({
    required this.chewieCtrl,
    required this.videoReady,
    required this.error,
    required this.lessonTitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          children: [
            // ── Player / states ──
            if (error != null)
              _VideoUnavailable()
            else if (videoReady && chewieCtrl != null)
              Chewie(controller: chewieCtrl!)
            else
              const Center(
                child: CircularProgressIndicator(
                  color: DS.primary,
                  strokeWidth: 2.5,
                ),
              ),

            // ── Back button ──
            Positioned(
              top: DS.s8,
              left: DS.s8,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(DS.s8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
            ),

            // ── Lesson title overlay (shown when not playing) ──
            if (!videoReady || error != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    DS.s14,
                    DS.s20,
                    DS.s14,
                    DS.s14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.80),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lessonTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoUnavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white54,
              size: 32,
            ),
          ),
          const SizedBox(height: DS.s14),
          const Text(
            'Video Coming Soon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: DS.s6),
          Text(
            'This lecture will be available shortly.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLAYER TAB BAR
// ─────────────────────────────────────────────
class _PlayerTabBar extends StatelessWidget {
  final TabController tabCtrl;
  const _PlayerTabBar({required this.tabCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: tabCtrl,
        labelColor: DS.primary,
        unselectedLabelColor: DS.textSecondary,
        indicatorColor: DS.primary,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.playlist_play_rounded, size: 16),
                SizedBox(width: DS.s6),
                Text('Lessons'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.picture_as_pdf_outlined, size: 14),
                SizedBox(width: DS.s6),
                Text('PDF Notes'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded, size: 14),
                SizedBox(width: DS.s6),
                Text('Info'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LESSONS TAB
// ─────────────────────────────────────────────
class _LessonsTab extends StatefulWidget {
  final AsyncValue<List<Chapter>> chaptersAsync;
  final AsyncValue<List<Lesson>> lessonsAsync;
  final String? activeLessonId;
  final void Function(Lesson) onLessonTap;

  const _LessonsTab({
    required this.chaptersAsync,
    required this.lessonsAsync,
    required this.activeLessonId,
    required this.onLessonTap,
  });

  @override
  State<_LessonsTab> createState() => _LessonsTabState();
}

class _LessonsTabState extends State<_LessonsTab> {
  final Set<String> _expanded = {};

  @override
  void didUpdateWidget(_LessonsTab old) {
    super.didUpdateWidget(old);
    widget.chaptersAsync.whenData((chapters) {
      widget.lessonsAsync.whenData((lessons) {
        final active = lessons
            .where((l) => l.id == widget.activeLessonId)
            .firstOrNull;
        if (active != null && !_expanded.contains(active.chapterId)) {
          setState(() => _expanded.add(active.chapterId));
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.chaptersAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (e, _) => _TabError(message: 'Error: $e'),
      data: (chapters) => widget.lessonsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
        ),
        error: (e, _) => _TabError(message: 'Error: $e'),
        data: (lessons) {
          if (lessons.isEmpty) {
            return _TabEmpty(
              icon: Icons.playlist_play_rounded,
              message: 'No lessons yet',
            );
          }

          // No chapters → flat list
          if (chapters.isEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s12,
                DS.s16,
                DS.s24,
              ),
              itemCount: lessons.length,
              itemBuilder: (_, i) => _LessonTile(
                lesson: lessons[i],
                isActive: lessons[i].id == widget.activeLessonId,
                indent: false,
                onTap: () => widget.onLessonTap(lessons[i]),
              ),
            );
          }

          // Grouped by chapter
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(0, DS.s8, 0, DS.s24),
            itemCount: chapters.length,
            itemBuilder: (_, ci) {
              final chapter = chapters[ci];
              final chLessons =
                  lessons.where((l) => l.chapterId == chapter.id).toList()
                    ..sort((a, b) => a.position.compareTo(b.position));
              final isExpanded = _expanded.contains(chapter.id);
              final hasActive = chLessons.any(
                (l) => l.id == widget.activeLessonId,
              );

              return Column(
                children: [
                  // Chapter header
                  GestureDetector(
                    onTap: () => setState(
                      () => isExpanded
                          ? _expanded.remove(chapter.id)
                          : _expanded.add(chapter.id),
                    ),
                    child: _ChapterHeader(
                      title: chapter.title,
                      lessonCount: chLessons.length,
                      isExpanded: isExpanded,
                      hasActive: hasActive,
                    ),
                  ),

                  // Lesson tiles
                  if (isExpanded)
                    ...chLessons.asMap().entries.map(
                      (e) => _LessonTile(
                        lesson: e.value,
                        isActive: e.value.id == widget.activeLessonId,
                        indent: true,
                        isLast: e.key == chLessons.length - 1,
                        onTap: () => widget.onLessonTap(e.value),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHAPTER HEADER
// ─────────────────────────────────────────────
class _ChapterHeader extends StatelessWidget {
  final String title;
  final int lessonCount;
  final bool isExpanded;
  final bool hasActive;

  const _ChapterHeader({
    required this.title,
    required this.lessonCount,
    required this.isExpanded,
    required this.hasActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      decoration: BoxDecoration(
        color: isExpanded
            ? DS.primaryLight
            : hasActive
            ? DS.primary.withOpacity(0.04)
            : DS.surfaceVariant,
        border: Border(
          bottom: BorderSide(
            color: isExpanded ? DS.primary.withOpacity(0.20) : DS.border,
            width: 1,
          ),
          top: BorderSide(color: DS.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Chapter icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isExpanded ? DS.primary.withOpacity(0.15) : DS.surface,
              borderRadius: BorderRadius.circular(DS.radiusSm),
              border: Border.all(
                color: isExpanded ? DS.primary.withOpacity(0.25) : DS.border,
                width: 1,
              ),
            ),
            child: Icon(
              Icons.folder_outlined,
              size: 16,
              color: isExpanded ? DS.primary : DS.textSecondary,
            ),
          ),
          const SizedBox(width: DS.s12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isExpanded ? DS.primaryDark : DS.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: DS.s2),
                Text(
                  '$lessonCount lesson${lessonCount == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: isExpanded
                        ? DS.primary.withOpacity(0.70)
                        : DS.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isExpanded ? DS.primary : DS.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LESSON TILE
// ─────────────────────────────────────────────
class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final bool isActive;
  final bool indent;
  final bool isLast;
  final VoidCallback onTap;

  const _LessonTile({
    required this.lesson,
    required this.isActive,
    required this.indent,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.fromLTRB(
          indent ? DS.s28 : DS.s16,
          DS.s10,
          DS.s16,
          DS.s10,
        ),
        decoration: BoxDecoration(
          color: isActive ? DS.primary.withOpacity(0.06) : DS.surface,
          border: Border(
            bottom: BorderSide(
              color: isLast ? Colors.transparent : DS.border,
              width: 0.8,
            ),
            left: isActive
                ? const BorderSide(color: DS.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Play icon tile
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF2B5BB8), DS.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isActive ? null : DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: DS.primary.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isActive ? Colors.white : DS.primary,
                size: 20,
              ),
            ),

            const SizedBox(width: DS.s12),

            // Lesson info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      color: isActive ? DS.primaryDark : DS.textPrimary,
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DS.s4),

                  // Meta row
                  Row(
                    children: [
                      if (lesson.durationMin > 0) ...[
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: isActive
                              ? DS.primary.withOpacity(0.70)
                              : DS.textHint,
                        ),
                        const SizedBox(width: DS.s3),
                        Text(
                          '${lesson.durationMin} min',
                          style: TextStyle(
                            color: isActive
                                ? DS.primary.withOpacity(0.70)
                                : DS.textSecondary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: DS.s8),
                      ],
                      if (!hasVideo)
                        _MiniPill(label: 'Soon', color: DS.textSecondary),
                      if (lesson.isFreePreview)
                        _MiniPill(label: 'Free', color: DS.teal),
                    ],
                  ),
                ],
              ),
            ),

            // Playing indicator
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(left: DS.s8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: DS.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s6, vertical: DS.s2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.25), width: 1),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}

// ─────────────────────────────────────────────
// PDFS TAB
// ─────────────────────────────────────────────
class _PdfsTab extends ConsumerWidget {
  final AsyncValue<List<SubtopicPdf>> pdfsAsync;
  final String courseId;
  const _PdfsTab({required this.pdfsAsync, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;

    return pdfsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (e, _) => _TabError(message: 'Error: $e'),
      data: (pdfs) {
        if (pdfs.isEmpty) {
          return _TabEmpty(
            icon: Icons.picture_as_pdf_outlined,
            message: 'No PDF notes yet',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(DS.s16),
          itemCount: pdfs.length,
          separatorBuilder: (_, __) => const SizedBox(height: DS.s10),
          itemBuilder: (_, i) => _PdfTile(pdf: pdfs[i], isEnrolled: isEnrolled),
        );
      },
    );
  }
}

class _PdfTile extends StatelessWidget {
  final SubtopicPdf pdf;
  final bool isEnrolled;
  const _PdfTile({required this.pdf, required this.isEnrolled});

  @override
  Widget build(BuildContext context) {
    final sizeKb = pdf.fileSizeKb;
    final sizeLabel = sizeKb == null || sizeKb <= 0
        ? ''
        : sizeKb >= 1024
        ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
        : '$sizeKb KB';
    final fileUrl = pdf.fileUrl;
    final hasFile = fileUrl != null && fileUrl.isNotEmpty;

    return GestureDetector(
      onTap: !isEnrolled
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Enroll in this course to access PDF notes.'),
              ),
            )
          : !hasFile
          ? () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This PDF is not available yet.')),
            )
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PdfViewerScreen(title: pdf.title, fileUrl: fileUrl),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
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
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: DS.error,
                size: 22,
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pdf.title,
                    style: TextStyle(
                      color: isEnrolled ? DS.textPrimary : DS.textHint,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (sizeLabel.isNotEmpty) ...[
                    const SizedBox(height: DS.s2),
                    Text(
                      sizeLabel,
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isEnrolled ? DS.primaryLight : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(
                isEnrolled
                    ? Icons.open_in_new_rounded
                    : Icons.lock_outline_rounded,
                color: isEnrolled ? DS.primary : DS.textHint,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INFO TAB
// ─────────────────────────────────────────────
class _InfoTab extends StatelessWidget {
  final AsyncValue<dynamic> courseAsync;
  const _InfoTab({required this.courseAsync});

  @override
  Widget build(BuildContext context) {
    return courseAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (e, _) => _TabError(message: 'Error: $e'),
      data: (course) => ListView(
        padding: const EdgeInsets.all(DS.s16),
        children: [
          // ── About ──
          if (course.description != null &&
              (course.description as String).isNotEmpty) ...[
            _InfoSectionLabel(
              label: 'About this course',
              icon: Icons.info_outline_rounded,
              color: DS.primary,
            ),
            const SizedBox(height: DS.s10),
            Container(
              padding: const EdgeInsets.all(DS.s14),
              decoration: BoxDecoration(
                color: DS.surface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: DS.border, width: 1.2),
              ),
              child: Text(
                course.description!,
                style: const TextStyle(
                  color: DS.textPrimary,
                  fontSize: 13.5,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: DS.s20),
          ],

          // ── What you'll learn ──
          if ((course.whatYoullLearn as List).isNotEmpty) ...[
            _InfoSectionLabel(
              label: 'What you\'ll learn',
              icon: Icons.check_circle_outline_rounded,
              color: DS.success,
            ),
            const SizedBox(height: DS.s10),
            Container(
              padding: const EdgeInsets.all(DS.s14),
              decoration: BoxDecoration(
                color: DS.surface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: DS.border, width: 1.2),
              ),
              child: Column(
                children: (course.whatYoullLearn as List)
                    .map<Widget>(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: DS.s10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: DS.s2),
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: DS.success,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: DS.s10),
                            Expanded(
                              child: Text(
                                item as String,
                                style: const TextStyle(
                                  color: DS.textPrimary,
                                  fontSize: 13.5,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: DS.s20),
          ],

          // ── Quick info chips ──
          _InfoSectionLabel(
            label: 'Course details',
            icon: Icons.school_outlined,
            color: DS.indigo,
          ),
          const SizedBox(height: DS.s10),
          Wrap(
            spacing: DS.s8,
            runSpacing: DS.s8,
            children: [
              _InfoChip(
                Icons.person_outline_rounded,
                course.teacherName ?? 'Instructor',
              ),
              _InfoChip(Icons.bar_chart_rounded, course.courseClass),
              _InfoChip(Icons.flag_outlined, course.target),
              _InfoChip(
                Icons.workspace_premium_outlined,
                'Certificate on completion',
              ),
              _InfoChip(Icons.all_inclusive_rounded, 'Lifetime access'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSectionLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _InfoSectionLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: DS.s8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s8),
    decoration: BoxDecoration(
      color: DS.primaryLight,
      borderRadius: BorderRadius.circular(DS.radiusSm),
      border: Border.all(color: DS.primary.withOpacity(0.20), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: DS.primary, size: 13),
        const SizedBox(width: DS.s6),
        Text(
          label,
          style: const TextStyle(
            color: DS.primary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// TAB EMPTY STATE
// ─────────────────────────────────────────────
class _TabEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _TabEmpty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            child: Icon(icon, color: DS.textHint, size: 28),
          ),
          const SizedBox(height: DS.s14),
          Text(
            message,
            style: const TextStyle(
              color: DS.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TAB ERROR STATE
// ─────────────────────────────────────────────
class _TabError extends StatelessWidget {
  final String message;
  const _TabError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      style: const TextStyle(color: DS.textSecondary, fontSize: 13),
      textAlign: TextAlign.center,
    ),
  );
}
