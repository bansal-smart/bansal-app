import 'package:equatable/equatable.dart';

class Course extends Equatable {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? subject;
  final String? educatorName;
  final String? level;
  final String? targetExam;
  final String? thumbnailUrl;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final double rating;
  final int totalEnrolled;
  final int totalLessons;
  final int durationHours;
  final List<String> tags;
  final String? badge;
  final bool isFeatured;
  final bool isPublished;
  final List<String> whatYoullLearn;
  final List<String> requirements;
  final int sortOrder;
  final String? shortDescription;
  final String? educationLevel;
  final String? durationLabel;
  final String? mode;
  final String language;
  final List<String> subjectsCovered;
  final String? descriptionHtml;
  final List<String> includedServices;
  final String? centreId;
  final bool isGlobal;
  final DateTime? endDate;

  const Course({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.subject,
    this.educatorName,
    this.level,
    this.targetExam,
    this.thumbnailUrl,
    this.price = 0,
    this.originalPrice,
    this.discountPercent = 0,
    this.rating = 0,
    this.totalEnrolled = 0,
    this.totalLessons = 0,
    this.durationHours = 0,
    this.tags = const [],
    this.badge,
    this.isFeatured = false,
    this.isPublished = true,
    this.whatYoullLearn = const [],
    this.requirements = const [],
    this.sortOrder = 0,
    this.shortDescription,
    this.educationLevel,
    this.durationLabel,
    this.mode,
    this.language = 'English',
    this.subjectsCovered = const [],
    this.descriptionHtml,
    this.includedServices = const [],
    this.centreId,
    this.isGlobal = false,
    this.endDate,
  });

  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  factory Course.fromJson(Map<String, dynamic> j) => Course(
    id: j['id'] as String,
    slug: j['slug'] as String? ?? '',
    name: j['name'] as String? ?? '',
    description: j['description'] as String?,
    subject: j['subject'] as String?,
    educatorName: j['educator_name'] as String?,
    level: j['level'] as String?,
    targetExam: j['target_exam'] as String?,
    thumbnailUrl: j['thumbnail_url'] as String?,
    price: _toDouble(j['price']),
    originalPrice: j['original_price'] != null
        ? _toDouble(j['original_price'])
        : null,
    discountPercent: _toInt(j['discount_percent']) ?? 0,
    rating: _toDouble(j['rating']),
    totalEnrolled: _toInt(j['total_enrolled']) ?? 0,
    totalLessons: _toInt(j['total_lessons']) ?? 0,
    durationHours: _toInt(j['duration_hours']) ?? 0,
    tags: _toStringList(j['tags']),
    badge: j['badge'] as String?,
    isFeatured: j['is_featured'] as bool? ?? false,
    isPublished: j['is_published'] as bool? ?? true,
    whatYoullLearn: _toStringList(j['what_youll_learn']),
    requirements: _toStringList(j['requirements']),
    sortOrder: _toInt(j['sort_order']) ?? 0,
    shortDescription: j['short_description'] as String?,
    educationLevel: j['education_level'] as String?,
    durationLabel: j['duration_label'] as String?,
    mode: j['mode'] as String?,
    language: j['language'] as String? ?? 'English',
    subjectsCovered: _toStringList(j['subjects_covered']),
    descriptionHtml: j['description_html'] as String?,
    includedServices: _toStringList(j['included_services']),
    centreId: j['centre_id'] as String?,
    isGlobal: j['is_global'] as bool? ?? false,
    endDate: j['end_date'] != null
        ? DateTime.tryParse(j['end_date'] as String)
        : null,
  );

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static List<String> _toStringList(dynamic v) =>
      (v as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];

  @override
  List<Object?> get props => [id, name, targetExam, price, isFeatured];
}
