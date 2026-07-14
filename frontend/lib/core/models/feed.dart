import 'business.dart';

class FeedSection {
  const FeedSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.layout,
    required this.businesses,
  });

  final String key;
  final String title;
  final String subtitle;
  final String layout; // hero | horizontal | list | stack
  final List<BusinessCard> businesses;

  factory FeedSection.fromJson(Map<String, dynamic> j) => FeedSection(
        key: j['key'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String? ?? '',
        layout: j['layout'] as String,
        businesses: (j['businesses'] as List)
            .map((e) => BusinessCard.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Feed {
  const Feed({
    required this.greeting,
    required this.headline,
    required this.categories,
    required this.sections,
  });

  final String greeting;
  final String headline;
  final List<Category> categories;
  final List<FeedSection> sections;

  factory Feed.fromJson(Map<String, dynamic> j) => Feed(
        greeting: j['greeting'] as String,
        headline: j['headline'] as String,
        categories: (j['categories'] as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList(),
        sections: (j['sections'] as List)
            .map((e) => FeedSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
