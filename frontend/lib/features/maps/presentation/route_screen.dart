import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/location/location_service.dart';
import '../../../core/maps/geo_repository.dart';
import '../../../core/maps/map_service.dart';
import '../../../core/maps/map_types.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

/// UC-9 alternative flow "get directions": opens the route preview to [destination].
Future<void> showRoute(
  BuildContext context, {
  required GeoPoint destination,
  required String name,
  String? address,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RouteScreen(destination: destination, name: name, address: address),
    ),
  );
}

/// The route from the user to a business, drawn on our own map with the travel time and
/// distance. Turn-by-turn navigation is handed to Google Maps ("Start").
class RouteScreen extends ConsumerStatefulWidget {
  const RouteScreen({super.key, required this.destination, required this.name, this.address});

  final GeoPoint destination;
  final String name;
  final String? address;

  @override
  ConsumerState<RouteScreen> createState() => _RouteScreenState();
}

enum _Phase { locating, loading, ready, noLocation, unavailable, noRoute, failed }

class _RouteScreenState extends ConsumerState<RouteScreen> {
  KhojloMapController? _map;
  TravelMode _mode = TravelMode.car;
  _Phase _phase = _Phase.locating;
  GeoPoint? _origin;
  final _routes = <TravelMode, RouteResult>{};
  int _requestId = 0;

  /// How much of the screen the header and the bottom card cover, so the route is fitted
  /// into the part of the map that stays visible.
  static const _topShare = 0.14;
  static const _bottomShare = 0.36;

  RouteResult? get _route => _routes[_mode];

  @override
  void initState() {
    super.initState();
    // After the first frame: locating updates app state, which can't happen mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _locate(prompt: false);
    });
  }

  Future<void> _locate({required bool prompt}) async {
    setState(() => _phase = _Phase.locating);
    final controller = ref.read(locationControllerProvider.notifier);
    final fix =
        (prompt ? null : ref.read(locationControllerProvider).fix) ??
        await controller.refresh(prompt: true);
    if (!mounted) return;
    if (fix == null) {
      setState(() => _phase = _Phase.noLocation);
      _fit([widget.destination]);
      return;
    }
    _origin = fix.point;
    await _loadRoute();
  }

  Future<void> _loadRoute() async {
    final origin = _origin;
    if (origin == null) return;
    final mode = _mode;
    final cached = _routes[mode];
    if (cached != null) {
      setState(() => _phase = _Phase.ready);
      _fit(cached.points);
      return;
    }
    final id = ++_requestId;
    setState(() => _phase = _Phase.loading);
    _fit([origin, widget.destination]);
    try {
      final route = await ref.read(geoRepositoryProvider).route(origin, widget.destination, mode);
      if (!mounted || id != _requestId) return;
      setState(() {
        _routes[mode] = route;
        _phase = _Phase.ready;
      });
      _fit(route.points);
    } on GeoLookupException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(
        () => _phase = switch (e.reason) {
          GeoLookupFailure.unavailable => _Phase.unavailable,
          GeoLookupFailure.notFound => _Phase.noRoute,
          GeoLookupFailure.failed => _Phase.failed,
        },
      );
    }
  }

  void _switchMode(TravelMode mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    if (_origin != null && _phase != _Phase.unavailable) _loadRoute();
  }

  /// Frames [points] in the map area between the header and the bottom card.
  void _fit(List<GeoPoint> points) {
    final bounds = GeoBounds.around(points, padding: 0.12);
    if (bounds == null) return;
    final span = bounds.north - bounds.south;
    final visible = 1 - _topShare - _bottomShare;
    _map?.fitBounds(
      GeoBounds(
        south: bounds.south - span * _bottomShare / visible,
        west: bounds.west,
        north: bounds.north + span * _topShare / visible,
        east: bounds.east,
      ),
    );
  }

  Future<void> _start() async {
    final opened = await ref
        .read(mapServiceProvider)
        .openDirections(widget.destination, walking: _mode == TravelMode.walk);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.ink,
            content: Text(
              'Couldn’t open Google Maps on this device.',
              style: AppType.sans(size: 13, color: Colors.white),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapService = ref.watch(mapServiceProvider);
    final origin = _origin;
    final route = _phase == _Phase.ready ? _route : null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          Positioned.fill(
            child: mapService.buildMap(
              center: widget.destination,
              zoom: 14,
              pins: [
                if (origin != null) MapPin(id: 'me', point: origin, kind: PinKind.user),
                MapPin(id: 'destination', point: widget.destination, kind: PinKind.selected),
              ],
              route: route?.points ?? const [],
              onCreated: (c) {
                _map = c;
                _fit(route?.points ?? [?origin, widget.destination]);
              },
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 12,
            left: 16,
            right: 16,
            child: PointerInterceptor(
              child: Row(
                children: [
                  GlassIconButton(
                    icon: Icons.close_rounded,
                    size: 44,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: GlassSurface(
                      radius: 16,
                      opacity: 0.85,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Text(
                        'Route to ${widget.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(size: 14, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            // Leaves the map's attribution (bottom left) visible below the card.
            bottom: MediaQuery.paddingOf(context).bottom + 40,
            child: PointerInterceptor(
              child: GlassSurface(
                radius: 24,
                opacity: 0.92,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ModeSwitch(mode: _mode, onChanged: _switchMode),
                    const SizedBox(height: 14),
                    _Summary(
                      phase: _phase,
                      route: route,
                      straightLine: origin == null
                          ? null
                          : distanceMeters(origin, widget.destination),
                    ),
                    if (widget.address != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.address!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55)),
                      ),
                    ],
                    _Note(
                      phase: _phase,
                      mode: _mode,
                      onRetry: _phase == _Phase.noLocation
                          ? () => _locate(prompt: true)
                          : _loadRoute,
                      onSettings:
                          ref.read(locationControllerProvider).status ==
                                  LocationStatus.deniedForever &&
                              !kIsWeb
                          ? ref.read(locationControllerProvider.notifier).openSettings
                          : null,
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: 'Start in Google Maps',
                      icon: Icons.navigation_rounded,
                      tone: ButtonTone.emerald,
                      onTap: _start,
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

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});
  final TravelMode mode;
  final ValueChanged<TravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(TravelMode value, IconData icon, String label) {
      final selected = value == mode;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: selected ? Colors.white : AppColors.inkA(0.6)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: AppType.sans(
                    size: 13,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.inkA(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.inkA(0.06),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option(TravelMode.car, Icons.directions_car_rounded, 'Car'),
          option(TravelMode.walk, Icons.directions_walk_rounded, 'Walk'),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.phase, required this.route, required this.straightLine});
  final _Phase phase;
  final RouteResult? route;
  final double? straightLine;

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    final (String title, String? subtitle) = switch (phase) {
      _Phase.locating => ('Finding you…', null),
      _Phase.loading => ('Finding the best route…', null),
      _Phase.ready when route != null => (
        // Free routing has no live traffic, so the time is approximate.
        '~${formatDuration(route.duration)}',
        formatDistance(route.distanceMeters),
      ),
      _ when straightLine != null => (
        '${formatDistance(straightLine!)} away',
        'in a straight line',
      ),
      _ => ('Directions', null),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (phase == _Phase.locating || phase == _Phase.loading) ...[
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(title, style: AppType.serif(size: 24))),
        if (subtitle != null) ...[
          const SizedBox(width: 10),
          Text(subtitle, style: AppType.sans(size: 14, color: AppColors.inkA(0.6))),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.phase, required this.mode, this.onRetry, this.onSettings});
  final _Phase phase;
  final TravelMode mode;
  final VoidCallback? onRetry;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final (String? text, String? action, VoidCallback? onAction) = switch (phase) {
      _Phase.noLocation when onSettings != null => (
        'Location is blocked for Khojlo, so we can’t draw the route from where you are.',
        'Settings',
        onSettings,
      ),
      _Phase.noLocation => (
        'Turn on location to see the route from where you are.',
        'Try again',
        onRetry,
      ),
      _Phase.unavailable => ('Route previews aren’t available right now.', null, null),
      _Phase.noRoute => (
        mode == TravelMode.walk
            ? 'We couldn’t find a walking route. Try by car.'
            : 'We couldn’t find a road route to this place.',
        null,
        null,
      ),
      _Phase.failed => ('Couldn’t load the route.', 'Try again', onRetry),
      _ => (null, null, null),
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: AppType.sans(size: 12.5, height: 1.4, color: AppColors.inkA(0.65)),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                action,
                style: AppType.sans(size: 13, weight: FontWeight.w600, color: AppColors.emerald),
              ),
            ),
        ],
      ),
    );
  }
}

/// "850 m", "4.3 km", "27 km".
String formatDistance(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = meters / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

/// "3 min", "45 min", "1 h 5 min".
String formatDuration(Duration d) {
  final minutes = math.max(1, (d.inSeconds / 60).round());
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return rest == 0 ? '${minutes ~/ 60} h' : '${minutes ~/ 60} h $rest min';
}
