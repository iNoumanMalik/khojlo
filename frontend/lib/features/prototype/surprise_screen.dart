import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/business.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import '../discovery/discovery_providers.dart';

/// Module 3 — "Surprise Me": a swipeable stack of every listed business, in a new
/// random order each time (uses /feed/surprise). Swipe or tap Skip for the next one;
/// after the last card, shuffle again.
class SurpriseScreen extends ConsumerStatefulWidget {
  const SurpriseScreen({super.key});

  @override
  ConsumerState<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends ConsumerState<SurpriseScreen> {
  int _index = 0;

  void _next() => setState(() => _index++);

  void _shuffleAgain() {
    setState(() => _index = 0);
    ref.invalidate(surpriseProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surpriseProvider);
    final total = async.valueOrNull?.length ?? 0;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          const Positioned.fill(child: MeshBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.chevron_left_rounded,
                        size: 38,
                        onTap: () => context.pop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('SURPRISE ME', style: AppType.label()),
                            if (total > 0 && _index < total)
                              Text(
                                '${_index + 1} of $total',
                                style: AppType.mono(
                                  size: 10.5,
                                  color: AppColors.inkA(0.45),
                                ),
                              ),
                          ],
                        ),
                      ),
                      GlassIconButton(
                        icon: Icons.shuffle_rounded,
                        size: 38,
                        onTap: _shuffleAgain,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: async.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.emerald,
                      ),
                    ),
                    error: (_, __) => Center(
                      child: Text(
                        'Couldn’t shuffle right now',
                        style: AppType.sans(color: AppColors.inkA(0.6)),
                      ),
                    ),
                    data: (list) => list.isEmpty
                        ? _message('Nothing to surprise you with yet')
                        : _index >= list.length
                        ? _finished(list.length)
                        : _stack(list),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
    child: Text(text, style: AppType.sans(color: AppColors.inkA(0.6))),
  );

  /// After the last card: every listed business has been shown once.
  Widget _finished(int total) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 36, color: AppColors.gold),
          const SizedBox(height: 14),
          Text(
            'You’ve seen all $total places',
            textAlign: TextAlign.center,
            style: AppType.serif(size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Shuffle again for a new order.',
            textAlign: TextAlign.center,
            style: AppType.sans(size: 13, color: AppColors.inkA(0.6)),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Shuffle again',
            icon: Icons.shuffle_rounded,
            expand: false,
            onTap: _shuffleAgain,
          ),
        ],
      ),
    ),
  );

  final _deck = GlobalKey<_SwipeDeckState>();

  Widget _stack(List<BusinessCard> list) {
    final current = list[_index];
    final next = _index + 1 < list.length ? list[_index + 1] : null;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            // Scales the fixed-size card down on short screens instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: _SwipeDeck(
                  key: _deck,
                  current: current,
                  next: next,
                  onSwiped: _next,
                  onTap: () => context.push('/business/${current.id}'),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Skip',
                  tone: AppColors.inkA(0.6),
                  // The same fly-off as a swipe, not an instant jump.
                  onTap: () => _deck.currentState?.flyOut(-1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'View',
                  tone: ButtonTone.ink,
                  onTap: () => context.push('/business/${current.id}'),
                ),
              ),
            ],
          ),
        ),
        Text(
          '← swipe to explore →',
          style: AppType.mono(
            size: 10,
            color: AppColors.inkA(0.45),
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The card stack: the top card follows the finger and tilts; past a threshold (or
/// a quick flick) it flies off and the next card rises into place, otherwise it
/// springs back. [flyOut] runs the same animation for the Skip button.
class _SwipeDeck extends StatefulWidget {
  const _SwipeDeck({
    super.key,
    required this.current,
    required this.next,
    required this.onSwiped,
    required this.onTap,
  });

  final BusinessCard current;
  final BusinessCard? next;
  final VoidCallback onSwiped;
  final VoidCallback onTap;

  @override
  State<_SwipeDeck> createState() => _SwipeDeckState();
}

class _SwipeDeckState extends State<_SwipeDeck>
    with SingleTickerProviderStateMixin {
  static const _cardWidth = 280.0;
  static const _flyDistance = 520.0;

  late final _anim = AnimationController(vsync: this);
  Offset _drag = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _leaving = false;

  /// Where the top card is: follows the finger, or the running animation.
  Offset get _offset => _drag;

  @override
  void initState() {
    super.initState();
    _anim.addListener(
      () => setState(() => _drag = Offset.lerp(_from, _to, _anim.value)!),
    );
  }

  @override
  void didUpdateWidget(_SwipeDeck old) {
    super.didUpdateWidget(old);
    if (old.current.id != widget.current.id) {
      // A new top card: start centred.
      _anim.stop();
      _anim.value = 0;
      _drag = _from = _to = Offset.zero;
      _leaving = false;
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _animateTo(Offset target, {required bool leave, double velocity = 0}) {
    _from = _offset;
    _to = target;
    _leaving = leave;
    final distance = (target - _from).distance;
    final ms = leave
        ? (velocity > 0 ? (distance / velocity * 1000).clamp(140, 320) : 300)
              .round()
        : 260;
    _anim.duration = Duration(milliseconds: ms);
    _anim.value = 0;
    _anim
        .animateTo(1, curve: leave ? Curves.easeOutCubic : Curves.easeOutBack)
        .whenCompleteOrCancel(() {
          if (!mounted) return;
          if (leave && _leaving) widget.onSwiped();
        });
  }

  /// Throw the top card off to the left (-1) or right (1).
  void flyOut(int direction) {
    if (_leaving) return;
    _animateTo(Offset(direction * _flyDistance, -30), leave: true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_leaving) return;
    _anim.stop();
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_leaving) return;
    final vx = d.velocity.pixelsPerSecond.dx;
    final flung = vx.abs() > 700;
    if (_drag.dx.abs() > _cardWidth * 0.35 || flung) {
      final dir = (flung ? vx : _drag.dx).sign.toInt();
      _animateTo(
        Offset(dir * _flyDistance, _drag.dy + 40),
        leave: true,
        velocity: vx.abs(),
      );
    } else {
      _animateTo(Offset.zero, leave: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offset;
    final progress = (offset.dx.abs() / (_cardWidth * 0.8)).clamp(0.0, 1.0);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (widget.next != null)
          // The next card rises and straightens as the top one leaves.
          Transform.translate(
            offset: Offset(0, 14 * (1 - progress)),
            child: Transform.rotate(
              angle: 0.04 * (1 - progress),
              child: Transform.scale(
                scale: 0.94 + 0.06 * progress,
                child: RepaintBoundary(
                  child: _Card(business: widget.next!, behind: true),
                ),
              ),
            ),
          ),
        GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTap: widget.onTap,
          child: Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: offset.dx / _cardWidth * 0.25,
              child: RepaintBoundary(child: _Card(business: widget.current)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.business, this.behind = false});
  final BusinessCard business;

  /// The next card, waiting under the top one.
  final bool behind;

  @override
  Widget build(BuildContext context) {
    final meta = [
      business.ratingLabel,
      business.priceLabel,
      if (business.distanceLabel.isNotEmpty) business.distanceLabel,
    ].join('  ·  ');
    return Container(
      width: 280,
      height: 380,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: behind ? 0.1 : 0.2),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImageTile(
            height: 220,
            tone: business.tone,
            radius: 18,
            photo: business.cover,
          ),
          const SizedBox(height: 14),
          Text(
            business.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppType.serif(size: 22, height: 1.15),
          ),
          const SizedBox(height: 4),
          Text(
            business.typeLabel ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6)),
          ),
          const Spacer(),
          Text(
            meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.mono(size: 12, color: AppColors.inkA(0.7)),
          ),
        ],
      ),
    );
  }
}
