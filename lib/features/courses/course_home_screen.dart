import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'data/courses_providers.dart';
import 'data/models/course.dart';
import 'data/models/folder.dart';
import '../enrollments/data/repositories/enrollments_repository.dart';

const _kPrimary      = Color(0xFFF97015);
const _kPrimaryLight = Color(0xFFFFF0E6);
const _kBg           = Color(0xFFF5F6FA);
const _kSurface      = Color(0xFFFFFFFF);
const _kBorder       = Color(0xFFE8EAF0);
const _kText         = Color(0xFF111827);
const _kSub          = Color(0xFF6B7280);
const _kIndigo       = Color(0xFF6366F1);
const _kIndigoLight  = Color(0xFFEEF2FF);
const _kGreen        = Color(0xFF10B981);
const _kGreenLight   = Color(0xFFECFDF5);
const _kAmber        = Color(0xFFF59E0B);
const _kAmberLight   = Color(0xFFFFFBEB);
const _kRed          = Color(0xFFEF4444);

// ─────────────────────────────────────────────
// COURSE HOME SCREEN
// ─────────────────────────────────────────────
class CourseHomeScreen extends ConsumerStatefulWidget {
  final String courseId;
  const CourseHomeScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseHomeScreen> createState() => _CourseHomeScreenState();
}

class _CourseHomeScreenState extends ConsumerState<CourseHomeScreen> {
  @override
  void initState() {
    super.initState();
    EnrollmentsRepository().touchLastAccessed(widget.courseId);
  }

  @override
  Widget build(BuildContext context) {
    final courseAsync  = ref.watch(courseDetailProvider(widget.courseId));
    final foldersAsync = ref.watch(courseFoldersProvider(widget.courseId));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _kBg,
        body: foldersAsync.when(
          loading: () => _LoadingState(
            courseName: courseAsync.valueOrNull?.name ?? 'Course',
            onBack: () => context.pop(),
          ),
          error: (e, _) => _ErrorState(
            message: 'Error: $e',
            onBack: () => context.pop(),
          ),
          data: (folders) => _CourseBody(
            courseId: widget.courseId,
            folders: folders,
            course: courseAsync.valueOrNull,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COURSE BODY
// ─────────────────────────────────────────────
class _CourseBody extends StatelessWidget {
  final String courseId;
  final List<CourseFolder> folders;
  final Course? course;

  const _CourseBody({
    required this.courseId,
    required this.folders,
    required this.course,
  });

  bool get _showExpiry {
    if (course?.courseEndDate == null) return false;
    final days = course!.courseEndDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 7;
  }

  List<CourseFolder> get _moduleFolders =>
      folders.length <= 4 ? folders : folders.sublist(0, 4);

  List<CourseFolder> get _listFolders =>
      folders.length <= 4 ? [] : folders.sublist(4);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CourseHeader(course: course),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showExpiry)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _ExpiryBanner(endDate: course!.courseEndDate!),
                  ),

                if (course != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      '${folders.fold<int>(0, (s, f) => s + (f.itemCount > 0 ? f.itemCount : 1))} Items available in this course',
                      style: const TextStyle(
                        fontSize: 13,
                        color: _kPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                if (course?.teacherName != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _EducatorRow(course: course!),
                  ),

                if (folders.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Text(
                      'Learning Modules',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _kText,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ModuleGrid(
                      folders: _moduleFolders,
                      courseId: courseId,
                    ),
                  ),

                  if (_listFolders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._listFolders.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _FolderListTile(
                          folder: e.value,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push(
                              '/my-courses/$courseId/folder/${e.value.id}',
                              extra: e.value.name,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ] else
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: _EmptyFolders(),
                  ),

              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// COURSE HEADER
// ─────────────────────────────────────────────
class _CourseHeader extends StatelessWidget {
  final Course? course;
  const _CourseHeader({required this.course});

  @override
  Widget build(BuildContext context) {
    final hasThumbnail = course?.thumbnailUrl?.isNotEmpty == true;
    final topPad = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: hasThumbnail
            ? null
            : const LinearGradient(
                colors: [Color(0xFF1A2A4A), Color(0xFF162236)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Stack(
        children: [
          if (hasThumbnail)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: course!.thumbnailUrl!,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) =>
                        Container(color: const Color(0xFF1A2A4A)),
                    errorWidget: (ctx, url, err) =>
                        Container(color: const Color(0xFF1A2A4A)),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000), // black 40%
                          Color(0xBF000000), // black 75%
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (!hasThumbnail)
            Positioned.fill(child: _DotPattern()),

          Padding(
            padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0x26FFFFFF), // white 15%
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0x26FFFFFF), // white 15%
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bookmark_border_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (course != null)
                  Row(
                    children: [
                      _TagPill(label: course!.target.toUpperCase()),
                      const SizedBox(width: 8),
                      const _TagPill(
                        label: 'ADVANCED',
                        color: Color(0x1AFFFFFF), // white 10%
                      ),
                    ],
                  ),

                const SizedBox(height: 10),

                Text(
                  course?.name ?? 'Course',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final Color? color;
  const _TagPill({required this.label, this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color ?? const Color(0xD9F97015), // primary 85%
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
  );
}

class _DotPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotGridPainter(), size: Size.infinite);
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF) // white 4%
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// EDUCATOR ROW
// ─────────────────────────────────────────────
class _EducatorRow extends StatelessWidget {
  final Course course;
  const _EducatorRow({required this.course});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 40,
        height: 22,
        child: Stack(
          children: [
            _MiniAvatar(left: 0, color: _kPrimary),
            _MiniAvatar(left: 12, color: _kIndigo),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Text(
        course.teacherName ?? 'Educator',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kText,
        ),
      ),
      const SizedBox(width: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _kPrimaryLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '+2k',
          style: TextStyle(
            fontSize: 10,
            color: _kPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _MiniAvatar extends StatelessWidget {
  final double left;
  final Color color;
  const _MiniAvatar({required this.left, required this.color});

  @override
  Widget build(BuildContext context) => Positioned(
    left: left,
    child: Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Color.fromRGBO(color.r.toInt(), color.g.toInt(), color.b.toInt(), 0.20),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(Icons.person_rounded, size: 12, color: color),
    ),
  );
}

// ─────────────────────────────────────────────
// MODULE GRID (2×2)
// ─────────────────────────────────────────────
// All folders use the generic folder icon.
// Content-type icons (live-class, exam, pdf, video) are only used inside folder content lists.
String _svgForFolder(String name) => 'assets/SVGs/folder-blank.svg';

class _ModuleGrid extends StatelessWidget {
  final List<CourseFolder> folders;
  final String courseId;

  const _ModuleGrid({required this.folders, required this.courseId});

  static const _moduleConfigs = [
    _ModuleConfig(_kRed,    Color(0xFFFEF2F2)),
    _ModuleConfig(_kIndigo, _kIndigoLight),
    _ModuleConfig(_kAmber,  _kAmberLight),
    _ModuleConfig(_kGreen,  _kGreenLight),
  ];

  @override
  Widget build(BuildContext context) {
    final count = folders.length.clamp(0, 4);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: count,
      itemBuilder: (_, i) {
        final cfg = _moduleConfigs[i % _moduleConfigs.length];
        return _ModuleTile(
          folder: folders[i],
          config: cfg,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(
              '/my-courses/$courseId/folder/${folders[i].id}',
              extra: folders[i].name,
            );
          },
        );
      },
    );
  }
}

class _ModuleConfig {
  final Color iconColor;
  final Color bgColor;
  const _ModuleConfig(this.iconColor, this.bgColor);
}

class _ModuleTile extends StatelessWidget {
  final CourseFolder folder;
  final _ModuleConfig config;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.folder,
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            _svgForFolder(folder.name),
            width: 52,
            height: 52,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// FOLDER LIST TILE (5th folder onwards)
// ─────────────────────────────────────────────
class _FolderListTile extends StatelessWidget {
  final CourseFolder folder;
  final VoidCallback onTap;

  const _FolderListTile({
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            _svgForFolder(folder.name),
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                if (folder.itemCount > 0)
                  Text(
                    '${folder.itemCount} Lectures available',
                    style: const TextStyle(fontSize: 12, color: _kSub),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _kSub, size: 20),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// EXPIRY BANNER
// ─────────────────────────────────────────────
class _ExpiryBanner extends StatelessWidget {
  final DateTime endDate;
  const _ExpiryBanner({required this.endDate});

  @override
  Widget build(BuildContext context) {
    final days = endDate.difference(DateTime.now()).inDays;
    final isUrgent = days <= 2;
    final accent = isUrgent ? _kRed : _kAmber;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFEF2F2) : _kAmberLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Color.fromRGBO(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), 0.30),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color.fromRGBO(accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isUrgent ? Icons.warning_rounded : Icons.access_time_rounded,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUrgent ? 'Access Expiring Soon!' : 'Course Access Reminder',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isUrgent ? _kRed : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Access expires in $days day${days == 1 ? '' : 's'}. '
                  '${isUrgent ? 'Renew now!' : 'Make the most of your time!'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color.fromRGBO(
                      accent.r.toInt(), accent.g.toInt(), accent.b.toInt(), 0.80),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY FOLDERS
// ─────────────────────────────────────────────
class _EmptyFolders extends StatelessWidget {
  const _EmptyFolders();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C38), _kPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x38F97015), // primary 22%
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 20),
        const Text(
          'No content yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _kText,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Course materials will appear here\nonce published by the educator.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _kSub, fontSize: 13.5, height: 1.55),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// LOADING STATE
// ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  final String courseName;
  final VoidCallback onBack;
  const _LoadingState({required this.courseName, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2A4A), Color(0xFF162236)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorState({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2A4A), Color(0xFF162236)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: _kRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _kSub, fontSize: 13.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
