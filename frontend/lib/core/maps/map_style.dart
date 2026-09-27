/// Google map styling in Khojlo's palette (cream land, soft teal water, quiet roads).
/// Other businesses' points of interest are hidden so Khojlo's own pins stand out.
const khojloMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f3eee4"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#6e665b"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#fbf6ee"}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#d9cfbf"}]},
  {"featureType": "landscape.natural", "elementType": "geometry", "stylers": [{"color": "#ece5d7"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "stylers": [{"visibility": "simplified"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#dfe8d6"}]},
  {"featureType": "poi.park", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8174"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#f6e2b8"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#e8cf9a"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#c5dfd8"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#5f8a80"}]}
]
''';
