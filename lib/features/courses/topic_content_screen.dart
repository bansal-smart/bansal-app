import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'data/courses_providers.dart';
import 'data/models/subtopic_pdf.dart';
import 'data/models/subtopic_video.dart';
import '../../core/error/app_exception.dart';
import 'youtube_player_screen.dart';
import 's3_video_player_screen.dart';
import 'pdf_viewer_screen.dart';

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
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const indigo = Color(0xFF6366F1);

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
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusXl = 28;
}

bool _isYoutubeUrl(String url) =>
    url.contains('youtube.com') || url.contains('youtu.be');

// ─────────────────────────────────────────────
// TOPIC CONTENT SCREEN (videos + PDFs for a topic)
// ─────────────────────────────────────────────
class TopicContentScreen extends ConsumerWidget {
  final String courseId;
  final String subjectId;
  final String topicId;
  final String topicName;

  const TopicContentScreen({
    super.key,
    required this.courseId,
    required this.subjectId,
    required this.topicId,
    required this.topicName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(topicVideosProvider(topicId));
    final pdfsAsync = ref.watch(topicPdfsProvider(topicId));
    final progressAsync = ref.watch(videoProgressProvider(courseId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            _Header(title: topicName),
            Expanded(
              child: videosAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: DS.primary, strokeWidth: 2.5),
                ),
                error: (e, _) => _ErrorBody(message: AppException.from(e).userMessage),
                data: (videos) => pdfsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: DS.primary, strokeWidth: 2.5),
                  ),
                  error: (e, _) => _ErrorBody(message: AppException.from(e).userMessage),
                  data: (pdfs) {
                    if (videos.isEmpty && pdfs.isEmpty) {
                      return const _EmptyContent();
                    }
                    final completed = progressAsync.valueOrNull ?? <String>{};
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                          DS.s16, DS.s20, DS.s16, DS.s32),
                      children: [
                        if (videos.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'Video Lectures',
                            svgAsset: 'assets/SVGs/video.svg',
                            count: videos.length,
                            color: DS.primary,
                          ),
                          const SizedBox(height: DS.s12),
                          ...videos.asMap().entries.map(
                                (e) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: e.key < videos.length - 1
                                        ? DS.s10
                                        : DS.s20,
                                  ),
                                  child: _VideoCard(
                                    video: e.value,
                                    courseId: courseId,
                                    isCompleted:
                                        completed.contains(e.value.id),
                                  ),
                                ),
                              ),
                        ],
                        if (pdfs.isNotEmpty) ...[
                          _SectionLabel(
                            label: 'PDF Notes',
                            svgAsset: 'assets/SVGs/pdf-document.svg',
                            count: pdfs.length,
                            color: DS.error,
                          ),
                          const SizedBox(height: DS.s12),
                          ...pdfs.asMap().entries.map(
                                (e) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom:
                                        e.key < pdfs.length - 1 ? DS.s10 : 0,
                                  ),
                                  child: _PdfCard(pdf: e.value),
                                ),
                              ),
                        ],
                      ],
                    );
                  },
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
                      'assets/SVGs/video.svg',
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
                          'Course Content',
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
// SECTION LABEL
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final String? svgAsset;
  final int count;
  final Color color;

  const _SectionLabel({
    required this.label,
    this.svgAsset,
    this.count = 0,
    this.color = DS.primary,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(DS.radiusSm),
        ),
        padding: const EdgeInsets.all(5),
        child: SvgPicture.asset(
          svgAsset ?? 'assets/SVGs/folder-blank.svg',
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(width: DS.s8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: DS.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      const SizedBox(width: DS.s8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// VIDEO CARD
// ─────────────────────────────────────────────
class _VideoCard extends ConsumerWidget {
  final SubtopicVideo video;
  final String courseId;
  final bool isCompleted;

  const _VideoCard({
    required this.video,
    required this.courseId,
    required this.isCompleted,
  });

  void _play(BuildContext context, WidgetRef ref) {
    final youtubeId = video.youtubeVideoId;
    final youtubeUrl = video.youtubeUrl;
    if ((youtubeId != null && youtubeId.isNotEmpty) ||
        (youtubeUrl != null && _isYoutubeUrl(youtubeUrl))) {
      final url = youtubeUrl ?? 'https://www.youtube.com/watch?v=$youtubeId';
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              YoutubePlayerScreen(videoUrl: url, title: video.title),
        ),
      );
    } else if (youtubeUrl != null && youtubeUrl.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              S3VideoPlayerScreen(videoUrl: youtubeUrl, title: video.title),
        ),
      );
    } else {
      return;
    }

    // Mark progress once the student opens the video.
    markVideoProgress(
      videoId: video.id,
      subtopicId: video.subtopicId,
      courseId: courseId,
      isCompleted: true,
    ).then((_) {
      ref.invalidate(videoProgressProvider(courseId));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _play(context, ref);
      },
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(
                'assets/SVGs/video.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: DS.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: DS.s4),
                  Text(
                    'Subtopic: ${video.subtopicLabel?.trim().isNotEmpty == true
                        ? video.subtopicLabel!.trim()
                        : '—'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (video.durationLabel != null) ...[
                    const SizedBox(height: DS.s4),
                    Text(
                      video.durationLabel!,
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: DS.s8),
            if (isCompleted)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DS.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: DS.success,
                  size: 18,
                ),
              )
            else
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: DS.primary,
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
// PDF CARD
// ─────────────────────────────────────────────
class _PdfCard extends StatelessWidget {
  final SubtopicPdf pdf;
  const _PdfCard({required this.pdf});

  void _open(BuildContext context) {
    final url = pdf.fileUrl;
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(title: pdf.title, fileUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _open(context);
      },
      child: Container(
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              padding: const EdgeInsets.all(8),
              child: SvgPicture.asset(
                'assets/SVGs/pdf-document.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: DS.s12),
            Expanded(
              child: Text(
                pdf.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: DS.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: DS.s8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: const Icon(
                Icons.open_in_new_rounded,
                color: DS.primary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY / ERROR
// ─────────────────────────────────────────────
class _EmptyContent extends StatelessWidget {
  const _EmptyContent();

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
              boxShadow: [
                BoxShadow(
                  color: DS.primary.withOpacity(0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: DS.s16),
          const Text(
            'No content here yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s8),
          const Text(
            'Videos and PDFs will appear here once added.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
