import 'business.dart';

class SavedList {
  const SavedList({
    required this.id,
    required this.name,
    required this.tone,
    required this.count,
    required this.businesses,
  });

  final int id;
  final String name;
  final String tone;
  final int count;
  final List<BusinessCard> businesses;

  factory SavedList.fromJson(Map<String, dynamic> j) => SavedList(
        id: j['id'] as int,
        name: j['name'] as String,
        tone: j['tone'] as String? ?? 'gold',
        count: j['count'] as int? ?? 0,
        businesses: (j['businesses'] as List?)
                ?.map((e) => BusinessCard.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}
