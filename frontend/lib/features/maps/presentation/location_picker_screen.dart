import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/location/location_service.dart';
import '../../../core/maps/geo_repository.dart';
import '../../../core/maps/map_service.dart';
import '../../../core/maps/map_types.dart';
import '../../../core/maps/pin_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

/// What the owner confirmed in the picker.
class PickedLocation {
  const PickedLocation(this.point, {this.address});
  final GeoPoint point;

  /// The street address at the pin, when the server could look it up.
  final String? address;
}

/// Opens the map pin picker; resolves to the confirmed spot, or null if cancelled.
Future<PickedLocation?> showLocationPicker(BuildContext context, {GeoPoint? initial}) {
  return Navigator.of(context).push<PickedLocation>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LocationPickerScreen(initial: initial),
    ),
  );
}

/// Module 6: pin a business on the map (SRS FR-12, BR-7). The pin stays in the middle
/// while the owner drags the map under it; the address at the pin is looked up, and a
/// typed address can jump the map there.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});
  final GeoPoint? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _query = TextEditingController();
  KhojloMapController? _map;
  late GeoPoint _point;
  late final GeoPoint _start;
  late final double _startZoom;

  Timer? _reverseDebounce;
  Timer? _searchDebounce;
  int _lookupId = 0;
  GeoPlace? _place;
  bool _lookingUp = false;

  /// false once the server says address lookup isn't set up; the search box then hides.
  bool _lookupAvailable = true;
  List<GeoPlace> _results = const [];
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final fix = ref.read(locationControllerProvider).fix;
    if (initial != null && initial.isValid) {
      _start = initial;
      _startZoom = 17;
    } else if (fix != null) {
      _start = fix.point;
      _startZoom = 16;
    } else {
      _start = defaultMapCenter;
      _startZoom = 13;
    }
    _point = _start;
  }

  @override
  void dispose() {
    _query.dispose();
    _reverseDebounce?.cancel();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onCameraIdle(MapCamera camera) {
    setState(() => _point = camera.center);
    if (!_lookupAvailable) return;
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 600), _lookUpAddress);
  }

  Future<void> _lookUpAddress() async {
    final id = ++_lookupId;
    final point = _point;
    setState(() => _lookingUp = true);
    GeoPlace? place;
    try {
      place = await ref.read(geoRepositoryProvider).reverse(point);
    } on GeoLookupException catch (e) {
      if (e.reason == GeoLookupFailure.unavailable && mounted) {
        setState(() => _lookupAvailable = false);
      }
    }
    if (!mounted || id != _lookupId) return;
    setState(() {
      _place = place;
      _lookingUp = false;
    });
  }

  void _onQueryChanged(String text) {
    _searchDebounce?.cancel();
    if (text.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await ref.read(geoRepositoryProvider).search(text.trim());
        if (mounted && _query.text == text) setState(() => _results = results);
      } on GeoLookupException catch (e) {
        if (!mounted) return;
        setState(() {
          _results = const [];
          if (e.reason == GeoLookupFailure.unavailable) _lookupAvailable = false;
        });
      }
    });
  }

  void _jumpTo(GeoPlace place) {
    FocusScope.of(context).unfocus();
    setState(() {
      _results = const [];
      _query.text = place.label;
    });
    _map?.moveTo(place.point, zoom: 17);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final result = await ref.read(locationServiceProvider).locate(prompt: true, fresh: true);
    if (!mounted) return;
    setState(() => _locating = false);
    final fix = result.fix;
    if (fix != null) {
      await _map?.moveTo(fix.point, zoom: 18);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text(
            'Couldn’t get your location. Drag the map to your business instead.',
            style: AppType.sans(size: 13, color: Colors.white),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final mapService = ref.watch(mapServiceProvider);
    final valid = _point.isValid;
    final pin = pinSize(PinKind.picked);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: mapService.buildMap(
              center: _start,
              zoom: _startZoom,
              onCreated: (c) => _map = c,
              onCameraIdle: _onCameraIdle,
              onMapTap: () => FocusScope.of(context).unfocus(),
            ),
          ),
          // The fixed pin: its tip marks the map centre.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: Offset(0, -pin.height / 2),
                child: SizedBox.fromSize(
                  size: pin,
                  child: CustomPaint(painter: _PickedPinPainter()),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: PointerInterceptor(
              child: Column(
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close_rounded,
                        size: 44,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _lookupAvailable
                            ? _SearchBox(controller: _query, onChanged: _onQueryChanged)
                            : GlassSurface(
                                radius: 16,
                                opacity: 0.85,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Text(
                                  'Drag the map to put the pin on your business',
                                  style: AppType.sans(size: 13, color: AppColors.inkA(0.7)),
                                ),
                              ),
                      ),
                    ],
                  ),
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GlassSurface(
                      radius: 18,
                      opacity: 0.95,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          for (final place in _results)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.place_outlined, color: AppColors.emerald),
                              title: Text(
                                place.label,
                                style: AppType.sans(size: 13.5, weight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                place.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55)),
                              ),
                              onTap: () => _jumpTo(place),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: PointerInterceptor(
              child: GlassSurface(
                radius: 24,
                opacity: 0.95,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pin your business', style: AppType.serif(size: 20)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _lookingUp
                                ? 'Finding the address…'
                                : _place?.address ??
                                      'Drag the map so the pin sits on your entrance.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(size: 13, height: 1.4, color: AppColors.inkA(0.7)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _point.toString(),
                      style: AppType.mono(size: 10.5, color: AppColors.inkA(0.45)),
                    ),
                    if (!valid) ...[
                      const SizedBox(height: 6),
                      Text(
                        'That spot isn’t a valid location. Move the map to your business.',
                        style: AppType.sans(size: 12, color: AppColors.plum),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Tooltip(
                          message: 'Use my location',
                          child: _locating
                              ? const SizedBox(
                                  width: 52,
                                  height: 52,
                                  child: Padding(
                                    padding: EdgeInsets.all(15),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.emerald,
                                    ),
                                  ),
                                )
                              : GlassIconButton(
                                  icon: Icons.my_location_rounded,
                                  size: 52,
                                  onTap: _useMyLocation,
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Confirm pin',
                            onTap: valid
                                ? () => Navigator.of(
                                    context,
                                  ).pop(PickedLocation(_point, address: _place?.address))
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 16,
      opacity: 0.9,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: AppColors.inkA(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppType.sans(size: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                hintText: 'Search an address or area',
                hintStyle: AppType.sans(size: 14, color: AppColors.inkA(0.4)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickedPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => paintPin(canvas, size, PinKind.picked);

  @override
  bool shouldRepaint(_PickedPinPainter oldDelegate) => false;
}
