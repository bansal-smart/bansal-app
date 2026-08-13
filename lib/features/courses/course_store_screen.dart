import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import 'data/courses_providers.dart';
import 'data/models/course.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
abstract class _C {
  static const primary = Color(0xFFF97315);
  static const primaryLt = Color(0xFFFFF0E6);
  static const free = Color(0xFF10B981);
  static const surface = Color(0xFFFFFFFF);
  static const bg = Color(0xFFFFFBF8);
  static const border = Color(0xFFE5E7EB);
  static const textPri = Color(0xFF111827);
  static const textSub = Color(0xFF6B7280);
  static const chipText = Color(0xFF374151);
}

// ── Exam definitions ──────────────────────────────────────────────────────────
const _exams = ['All', 'JEE', 'NEET', 'Foundation'];

// Map display label → DB target value
const _examTarget = {'JEE': 'JEE', 'NEET': 'NEET', 'Foundation': 'Foundation'};

// Map display label → courseClass value used in DB
const _classLabels = <String, String>{
  'Class 8': '8',
  'Class 9': '9',
  'Class 10': '10',
  'Class 11': '11',
  'Class 12': '12',
  '12th Pass': '12th_pass',
};

// ── Screen ────────────────────────────────────────────────────────────────────
class CourseStoreScreen extends ConsumerStatefulWidget {
  const CourseStoreScreen({super.key});

  @override
  ConsumerState<CourseStoreScreen> createState() => _CourseStoreScreenState();
}

class _CourseStoreScreenState extends ConsumerState<CourseStoreScreen> {
  String _selectedExam = 'All';
  String _selectedClass = 'All Classes';

  // Build class chip labels relevant to the selected exam
  List<String> _classChips(String exam) {
    if (exam == 'JEE') {
      return ['All Classes', 'Class 11', 'Class 12', '12th Pass'];
    }
    if (exam == 'NEET') {
      return ['All Classes', 'Class 11', 'Class 12', '12th Pass'];
    }
    if (exam == 'Foundation') {
      return ['All Classes', 'Class 8', 'Class 9', 'Class 10'];
    }
    return ['All Classes'];
  }

  List<Course> _filter(List<Course> all) {
    var list = all;

    if (_selectedExam != 'All') {
      final target = _examTarget[_selectedExam]!;
      list = list.where((c) => c.target == target).toList();
    }

    if (_selectedClass != 'All Classes') {
      final cls = _classLabels[_selectedClass];
      if (cls != null) {
        list = list.where((c) => c.courseClass == cls).toList();
      }
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coursesProvider);
    final profile = ref.watch(profileSetupInfoProvider);

    // Pre-select the student's exam on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedExam == 'All' && profile.exam.isNotEmpty) {
        // Map stored exam value to display label
        final examLabel = _exams.firstWhere(
          (e) => e.toLowerCase() == profile.exam.toLowerCase(),
          orElse: () => 'All',
        );
        if (examLabel != 'All' && _selectedExam != examLabel) {
          setState(() => _selectedExam = examLabel);
        }
      }
    });

    final classChips = _classChips(_selectedExam);

    return Scaffold(
      backgroundColor: _C.bg,
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (e, _) => Center(
          child: Text(
            'Error loading courses',
            style: const TextStyle(color: _C.textSub),
          ),
        ),
        data: (courses) {
          final filtered = _filter(courses);
          return CustomScrollView(
            slivers: [
              // ── Orange banner ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: _C.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Course Store',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${courses.length} course${courses.length == 1 ? '' : 's'} available — explore by exam and class',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Exam filter chips ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _exams.map((exam) {
                        final active = exam == _selectedExam;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _selectedExam = exam;
                              _selectedClass = 'All Classes';
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active ? _C.primary : _C.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active ? _C.primary : _C.border,
                                ),
                                boxShadow: active
                                    ? [
                                        BoxShadow(
                                          color: _C.primary.withValues(
                                            alpha: 0.25,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    exam,
                                    style: TextStyle(
                                      color: active
                                          ? Colors.white
                                          : _C.chipText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (active && exam != 'All') ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // ── Class filter chips (only when exam is selected) ───────────
              if (_selectedExam != 'All')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: classChips.map((cls) {
                          final active = cls == _selectedClass;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedClass = cls),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: active ? _C.textPri : _C.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active ? _C.textPri : _C.border,
                                  ),
                                ),
                                child: Text(
                                  cls,
                                  style: TextStyle(
                                    color: active ? Colors.white : _C.chipText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),

              // ── Course count label ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    filtered.isEmpty
                        ? 'No courses found'
                        : '${filtered.length} course${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: _C.textSub,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // ── Empty state ───────────────────────────────────────────────
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _C.primaryLt,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: _C.primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No courses available',
                          style: TextStyle(
                            color: _C.textPri,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Try a different exam or class filter',
                          style: TextStyle(color: _C.textSub, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // ── Course cards ────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CourseCard(course: filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Course card ───────────────────────────────────────────────────────────────
class _CourseCard extends ConsumerWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolled =
        ref.watch(isEnrolledProvider(course.id)).valueOrNull ?? false;
    final hasThumbnail =
        course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  hasThumbnail
                      ? CachedNetworkImage(
                          imageUrl: course.thumbnailUrl!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _Placeholder(),
                        )
                      : _Placeholder(),
                  // Top-right exam·class badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${course.target} · Class ${course.courseClass}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Info ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exam label
                  Text(
                    course.target.toUpperCase(),
                    style: const TextStyle(
                      color: _C.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Course name
                  Text(
                    course.name,
                    style: const TextStyle(
                      color: _C.textPri,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Rating row
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFBBF24),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        course.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: _C.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Price
                  if (course.isCourseFree)
                    const Text(
                      'Free',
                      style: TextStyle(
                        color: _C.free,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Text(
                          '₹${course.salePrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: _C.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (course.mrp > course.salePrice) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${course.mrp.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: _C.textSub,
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  const SizedBox(height: 12),

                  // ── Action buttons ────────────────────────────────────────
                  Row(
                    children: [
                      // View Details
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/course/${course.id}'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _C.primary,
                            side: const BorderSide(color: _C.primary),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'View Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Enroll / Enrolled
                      Expanded(
                        child: enrolled
                            ? ElevatedButton(
                                onPressed: () =>
                                    context.push('/my-courses/${course.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _C.free,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Go to Course',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () =>
                                    context.push('/course/${course.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _C.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  course.isCourseFree ? 'Enroll' : 'Enroll Now',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ],
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

// ── Placeholder thumbnail ─────────────────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 160,
    color: _C.primary,
    child: const Center(
      child: Icon(Icons.school_rounded, color: Colors.white54, size: 48),
    ),
  );
}
