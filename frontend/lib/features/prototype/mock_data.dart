import '../../core/models/business.dart';

/// Static mock content for the remaining prototype screens (Modules 7, 8, 10).
class Mock {
  Mock._();

  static const places = <BusinessCard>[
    BusinessCard(
        id: 10,
        name: 'Glow Studio',
        tagline: 'Skin, nails & slow beauty',
        tone: 'coral',
        address: 'Blue Area',
        priceLevel: '\$\$',
        rating: 4.8,
        reviewCount: 121,
        saveCount: 58,
        isVerified: true,
        categoryName: 'Beauty',
        distanceKm: 0.6),
    BusinessCard(
        id: 1,
        name: 'Brew & Bloom',
        tagline: 'Specialty coffee & a wall of plants',
        tone: 'emerald',
        address: 'Blue Area',
        priceLevel: '\$\$',
        rating: 4.8,
        reviewCount: 214,
        saveCount: 96,
        isVerified: true,
        categoryName: 'Cafés',
        distanceKm: 0.3),
    BusinessCard(
        id: 4,
        name: 'Forno Italiano',
        tagline: 'Wood-fired Neapolitan pizza',
        tone: 'gold',
        address: 'F-7',
        priceLevel: '\$\$',
        rating: 4.7,
        reviewCount: 301,
        saveCount: 120,
        isVerified: true,
        categoryName: 'Restaurants',
        distanceKm: 1.1),
  ];
}
