import '../../core/models/business.dart';

/// Static mock content for the high-fidelity prototype screens (Modules 4–10).
/// These screens are UI-complete but not wired to the backend at the 30% stage.
class Mock {
  Mock._();

  static const places = <BusinessCard>[
    BusinessCard(
        id: 7,
        name: 'Sky Eleven Rooftop',
        tagline: '360° city views, craft cocktails',
        tone: 'plum',
        address: 'Blue Area',
        priceLevel: '\$\$\$',
        rating: 4.9,
        reviewCount: 312,
        saveCount: 210,
        isVerified: true,
        categoryName: 'Bars',
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

  static const recentSearches = ['Rooftop bars', 'Quiet cafés', 'Late-night ramen'];
  static const popularSearches = [
    'Hidden gems',
    'New this week',
    'Study spots',
    'Brunch',
    'Date night'
  ];

  static const conversations = <({String name, String tone, String last, String time, bool unread})>[
    (name: 'Sky Eleven Rooftop', tone: 'plum', last: 'Your table for 2 is confirmed for 8PM 🎉', time: '2m', unread: true),
    (name: 'Brew & Bloom', tone: 'emerald', last: 'We just dropped a new single-origin!', time: '1h', unread: true),
    (name: 'Forno Italiano', tone: 'gold', last: 'Thanks for stopping by — see you soon.', time: '3h', unread: false),
    (name: 'Glow Studio', tone: 'coral', last: 'Your appointment is booked for Saturday.', time: '1d', unread: false),
  ];

  static const reviews = <({String author, String tone, int rating, String body, String time})>[
    (author: 'Ayesha K.', tone: 'plum', rating: 5, body: 'Genuinely the best rooftop view in the city. Cocktails were incredible and service was warm.', time: '2d'),
    (author: 'Bilal R.', tone: 'emerald', rating: 5, body: 'Found this through Khojlo before it blew up. A real hidden gem.', time: '5d'),
    (author: 'Sana M.', tone: 'gold', rating: 4, body: 'Cosy and quiet — perfect for getting work done in the afternoon.', time: '1w'),
  ];

  static const notificationsToday = <({String icon, String title, String body, String tone})>[
    (icon: 'offer', title: 'New offer near you', body: 'Brew & Bloom: buy one, plant one — free seedling.', tone: 'gold'),
    (icon: 'trending', title: 'Trending tonight', body: 'Sky Eleven Rooftop is trending in Bars.', tone: 'plum'),
  ];
  static const notificationsEarlier = <({String icon, String title, String body, String tone})>[
    (icon: 'message', title: 'Forno Italiano replied', body: '“Thanks for stopping by — see you soon.”', tone: 'emerald'),
    (icon: 'ai', title: 'Kai found 3 new spots', body: 'Because you like quiet cafés.', tone: 'emerald'),
  ];
}
