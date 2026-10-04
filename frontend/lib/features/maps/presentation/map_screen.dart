import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../../core/location/location_service.dart';
import '../../../core/maps/geo_repository.dart';
import '../../../core/maps/map_service.dart';
import '../../../core/maps/map_types.dart';
import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../search/presentation/filter_sheet.dart';
import '../../search/presentation/widgets/explore_search_field.dart';
import '../../search/search_providers.dart';
import '../map_providers.dart';
import 'route_screen.dart';
import 'view_toggle.dart';

/// Module 6 — the Map tab (SRS UC-9, FR-12; SDD `MapService`). Follows the design's
/// "not a full-screen map" layout: search → map card → floating preview → nearby
/// carousel, with a filter button. Shares its keyword and filters with Explore.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _pages = PageController(viewportFraction: 0.82);
  KhojloMapController? _map;

  late final GeoPoint _startCenter;
  late final double _startZoom;

  /// Once the user has moved the map (or we showed a requested place), a late location
  /// fix no longer re-centres it.
  bool _settled = false;

  /// True while the carousel scrolls itself, so passing pages don't change the selection.
  bool _carouselMoving = false;

  MapResultsNotifier get _results => ref.read(mapResultsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _text.text = ref.read(searchControllerProvider).input;
    final focus = ref.read(mapFocusProvider);
    final fix = ref.read(locationControllerProvider).fix;
    if (focus != null) {
      _startCenter = focus.point;
      _startZoom = 16;
      _settled = true;
    } else if (fix != null) {
      _startCenter = fix.point;
      _startZoom = 14;
      _settled = true;
    } else {
      _startCenter = defaultMapCenter;
      _startZoom = defaultMapZoom;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationControllerProvider.notifier).ensureChecked();
      if (focus != null) _consumeFocus(focus);
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _consumeFocus(MapFocus focus) {
    ref.read(mapFocusProvider.notifier).state = null;
    _settled = true;
    _map?.moveTo(focus.point, zoom: 16);
    _results.select(focus.businessId);
  }

  Future<void> _locateMe() async {
    final fix = await ref.read(locationControllerProvider.notifier).refresh(prompt: true);
    if (!mounted) return;
    if (fix != null) {
      _settled = true;
      await _map?.moveTo(fix.point, zoom: 15);
      return;
    }
    // UC-9 exception: location unavailable.
    final status = ref.read(locationControllerProvider).status;
    _snack(
      switch (status) {
        LocationStatus.denied => 'Location permission was denied. The map shows Islamabad instead.',
        LocationStatus.deniedForever => 'Location is blocked for Khojlo. Allow it in Settings.',
        LocationStatus.serviceDisabled => 'Turn on location services to see where you are.',
        LocationStatus.unsupported => 'This device can’t share its location.',
        _ => 'Couldn’t find your location. Try again in a moment.',
      },
      action: status == LocationStatus.deniedForever && !kIsWeb
          ? SnackBarAction(
              label: 'Settings',
              textColor: AppColors.gold,
              onPressed: () => ref.read(locationControllerProvider.notifier).openSettings(),
            )
          : null,
    );
  }

  Future<void> _openFilters() async {
    _focus.unfocus();
    final current = ref.read(searchControllerProvider).filters;
    final result = await showFilterSheet(context, current);
    if (result != null) ref.read(searchControllerProvider.notifier).applyFilters(result);
  }

  /// UC-9 alternative flow: the route preview, then Google Maps for navigation.
  void _directions(BusinessCard b) {
    final point = b.location;
    if (point == null) return;
    showRoute(context, destination: point, name: b.name, address: b.address);
  }

  void _onPinTap(String id) {
    final businessId = int.tryParse(id);
    if (businessId != null) _results.select(businessId);
  }

  void _onCard(BusinessCard b) {
    if (ref.read(mapResultsProvider).selectedId == b.id) {
      context.push('/business/${b.id}');
      return;
    }
    _results.select(b.id);
    final point = b.location;
    final bounds = ref.read(mapResultsProvider).bounds;
    if (point != null && (bounds == null || !bounds.contains(point))) _map?.moveTo(point);
  }

  /// Keep the carousel on the selected place (after a pin tap or new results).
  void _syncCarousel(MapResultsState state) {
    final index = state.items.indexWhere((b) => b.id == state.selectedId);
    if (index < 0 || !_pages.hasClients) return;
    if ((_pages.page ?? 0).round() == index) return;
    _carouselMoving = true;
    _pages
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() => _carouselMoving = false);
  }

  void _snack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
          action: action,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapFocusProvider, (_, next) {
      if (next != null) _consumeFocus(next);
    });
    ref.listen(locationControllerProvider.select((s) => s.fix), (previous, next) {
      if (previous == null && next != null && !_settled) {
        _settled = true;
        _map?.moveTo(next.point, zoom: 14);
      }
    });
    ref.listen(mapResultsProvider, (_, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncCarousel(next);
      });
    });
    ref.listen(searchControllerProvider.select((s) => s.input), (_, next) {
      if (_text.text != next) {
        _text.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });

    final state = ref.watch(mapResultsProvider);
    final search = ref.watch(searchControllerProvider);
    final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
    final mapService = ref.watch(mapServiceProvider);
    final selected = state.selected;

    final pins = <MapPin>[
      if (fix != null) MapPin(id: 'me', point: fix.point, kind: PinKind.user),
      for (final b in state.items)
        MapPin(
          id: '${b.id}',
          point: b.location!,
          kind: b.id == state.selectedId ? PinKind.selected : PinKind.business,
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 64, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Map',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: AppType.serif(size: 30),
                      ),
                    ),
                    const ViewToggle(showingMap: true),
                  ],
                ),
                const SizedBox(height: 4),
                const _LocationIndicator(),
                const SizedBox(height: 12),
                ExploreSearchField(
                  controller: _text,
                  focusNode: _focus,
                  onChanged: ref.read(searchControllerProvider.notifier).onInputChanged,
                  onSubmitted: (q) {
                    _focus.unfocus();
                    ref.read(searchControllerProvider.notifier).submit(q);
                  },
                  onClear: ref.read(searchControllerProvider.notifier).clearQuery,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: mapService.buildMap(
                        center: _startCenter,
                        zoom: _startZoom,
                        pins: pins,
                        onPinTap: _onPinTap,
                        onMapTap: () {
                          _focus.unfocus();
                          _results.select(null);
                        },
                        onCreated: (controller) => _map = controller,
                        onCameraIdle: (camera) {
                          final moved =
                              (camera.center.latitude - _startCenter.latitude).abs() +
                              (camera.center.longitude - _startCenter.longitude).abs();
                          if (moved > 0.0005) _settled = true;
                          _results.onCameraIdle(camera.bounds);
                        },
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 64,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: _StatusChip(state: state, onRetry: _results.refresh),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: PointerInterceptor(
                        child: Semantics(
                          button: true,
                          label: 'Show my location',
                          child: GlassIconButton(
                            icon: Icons.my_location_rounded,
                            size: 44,
                            onTap: _locateMe,
                          ),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      right: 12,
                      bottom: selected == null ? 12 : 128,
                      child: PointerInterceptor(
                        child: FilterButton(
                          count: search.filters.activeCount,
                          size: 52,
                          onTap: _openFilters,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: selected == null
                            ? const SizedBox.shrink()
                            : PointerInterceptor(
                                key: ValueKey(selected.id),
                                child: _PreviewCard(
                                  business: selected,
                                  onOpen: () => context.push('/business/${selected.id}'),
                                  onDirections: () => _directions(selected),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: state.items.isEmpty
                ? _CarouselHint(state: state, hasSearch: search.showResults)
                : PageView.builder(
                    controller: _pages,
                    padEnds: false,
                    itemCount: state.items.length,
                    onPageChanged: (i) {
                      if (!_carouselMoving) _results.select(state.items[i].id);
                    },
                    itemBuilder: (_, i) {
                      final b = state.items[i];
                      return Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 16 : 6, right: 6),
                        child: _NearbyCard(
                          business: b,
                          selected: b.id == state.selectedId,
                          onTap: () => _onCard(b),
                        ),
                      );
                    },
                  ),
          ),
          // Room for the floating tab bar.
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// SDD Screen 1 "Location Indicator", shown here too: where the map thinks you are.
class _LocationIndicator extends ConsumerWidget {
  const _LocationIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationControllerProvider);
    final label = ref.watch(locationLabelProvider).valueOrNull;
    final text = location.isLocating && !location.hasFix
        ? 'Finding you…'
        : !location.hasFix
        ? 'Location off · showing Islamabad'
        : (label == null || label.isEmpty)
        ? 'Using your location'
        : 'Near $label';
    return Row(
      children: [
        Icon(
          location.hasFix ? Icons.near_me_rounded : Icons.location_disabled_rounded,
          size: 13,
          color: location.hasFix ? AppColors.emerald : AppColors.inkA(0.4),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(size: 13, color: AppColors.inkA(0.5)),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, required this.onRetry});
  final MapResultsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (String? text, bool busy, bool retry) = switch (state.status) {
      MapStatus.loading => ('Finding places…', true, false),
      MapStatus.error => ('Couldn’t load places · Retry', false, true),
      MapStatus.ready when state.capped => (
        'Showing ${state.items.length} of ${state.total} · zoom in for more',
        false,
        false,
      ),
      _ => (null, false, false),
    };
    if (text == null) return const SizedBox.shrink();
    return PointerInterceptor(
      child: GestureDetector(
        onTap: retry ? onRetry : null,
        child: GlassSurface(
          radius: 99,
          opacity: 0.85,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy) ...[
                const SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(strokeWidth: 1.6, color: AppColors.emerald),
                ),
                const SizedBox(width: 8),
              ],
              if (retry) ...[
                const Icon(Icons.refresh_rounded, size: 14, color: AppColors.plum),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    size: 11.5,
                    weight: FontWeight.w600,
                    color: retry ? AppColors.plum : AppColors.inkA(0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms);
  }
}

/// The floating card above the map for the tapped pin ("previews appear above pins").
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.business, required this.onOpen, required this.onDirections});

  final BusinessCard business;
  final VoidCallback onOpen;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final meta = [
      if (b.typeLabel != null) b.typeLabel!,
      if (b.distanceLabel.isNotEmpty) b.distanceLabel,
      if (b.isOpenNow != null) b.isOpenNow! ? 'Open now' : 'Closed',
    ].join(' · ');
    return GestureDetector(
      onTap: onOpen,
      child: GlassSurface(
        radius: 22,
        opacity: 0.92,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 84,
              child: ImageTile(tone: b.tone, radius: 16, photo: b.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(size: 17),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.mono(size: 10.5, color: AppColors.inkA(0.55)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (b.hasReviews) ...[
                        const Icon(Icons.star_rounded, size: 15, color: AppColors.gold),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        b.hasReviews ? b.rating.toStringAsFixed(1) : 'No reviews',
                        style: AppType.sans(size: 12.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          b.priceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.mono(size: 11, color: AppColors.inkA(0.55)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _DirectionsButton(onTap: onDirections),
          ],
        ),
      ),
    );
  }
}

/// Round "Directions" button on the preview card (UC-9 alternative flow).
class _DirectionsButton extends StatelessWidget {
  const _DirectionsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Directions',
      child: Semantics(
        button: true,
        label: 'Directions',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
            child: const Icon(Icons.directions_rounded, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// One place in the "nearby" carousel under the map.
class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.business, required this.selected, required this.onTap});
  final BusinessCard business;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final meta = [
      if (b.distanceLabel.isNotEmpty) b.distanceLabel,
      b.ratingLabel,
      if (b.isOpenNow != null) b.isOpenNow! ? 'Open' : 'Closed',
    ].join(' · ');
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.whiteA(selected ? 0.95 : 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.inkA(0.06),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 80,
              child: ImageTile(tone: b.tone, radius: 14, photo: b.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.serif(size: 15),
                  ),
                  if (b.typeLabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      b.typeLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.mono(
                      size: 10.5,
                      color: b.isOpenNow == true ? AppColors.emerald : AppColors.inkA(0.5),
                    ),
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

class _CarouselHint extends StatelessWidget {
  const _CarouselHint({required this.state, required this.hasSearch});
  final MapResultsState state;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final text = switch (state.status) {
      MapStatus.idle || MapStatus.loading => 'Looking around this area…',
      MapStatus.error => 'Places couldn’t load. Tap Retry on the map.',
      MapStatus.ready =>
        hasSearch
            ? 'Nothing here matches your search. Zoom out or change filters.'
            : 'No places pinned in this area yet. Try zooming out.',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppType.sans(size: 13, height: 1.4, color: AppColors.inkA(0.5)),
        ),
      ),
    );
  }
}
