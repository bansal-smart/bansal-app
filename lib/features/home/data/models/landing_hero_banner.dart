class LandingHeroBanner {
  const LandingHeroBanner({
    required this.id,
    required this.imageUrl,
    required this.sortOrder,
    this.alt,
    this.link,
  });

  final String id;
  final String imageUrl;
  final String? alt;
  final String? link;
  final int sortOrder;

  factory LandingHeroBanner.fromJson(Map<String, dynamic> json) {
    return LandingHeroBanner(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      alt: json['alt'] as String?,
      link: json['link'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}
