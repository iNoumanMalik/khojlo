import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Length of the intro, in ms (pin drop → wordmark → tagline → a short hold).
const _introMs = 2100.0;

const splashTagline = 'FIND WHAT’S NEAR YOU';

/// Completes once the app's first frame is actually on screen.
///
/// On Android the native launch screen stays up until the first frame has been drawn
/// and the window shown — on a slow start, seconds after Flutter built it — and
/// MainActivity reports that moment. Elsewhere it is the first rasterized frame.
Future<void> firstFrameShown() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await const MethodChannel('khojlo/launch').invokeMethod<void>('firstFrameShown');
      return;
    } catch (_) {
      // not our MainActivity: fall back to the rasterized frame
    }
  }
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
}

/// The launch animation, played once per cold start above the whole app.
///
/// The gold→emerald pin drops onto the cream page, the gold "places" scattered around
/// drift into it, and the wordmark rises beside it — ending on the app-icon layout.
/// Then the app opens through the hole in the pin. Underneath, the router restores the
/// session and moves to onboarding or home meanwhile; the reveal waits for both
/// ([ready] and the intro), the pin breathing if the session is slow.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.ready, this.shown, required this.child});

  /// The session restore has finished, so the router is on the first real screen.
  final bool ready;

  /// Completes when the splash is on screen, which starts the intro. Defaults to
  /// [firstFrameShown].
  final Future<void>? shown;
  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with TickerProviderStateMixin {
  // The route change under the overlay animates; let it finish before revealing it.
  static const _routeSettle = Duration(milliseconds: 450);

  late final _intro =
      AnimationController(vsync: this, duration: Duration(milliseconds: _introMs.round()));
  late final _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final _exit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 850));
  final _stageKey = GlobalKey();
  final _pinKey = GlobalKey();
  _PinGeometry _pin = _PinGeometry(56);
  Timer? _notShownTimeout;
  Offset? _exitHole;
  bool _started = false;
  bool _reduceMotion = false;
  bool _routeSettled = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    if (widget.ready) _settleRoute();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _start();
    }
  }

  @override
  void didUpdateWidget(SplashOverlay old) {
    super.didUpdateWidget(old);
    if (widget.ready && !old.ready) _settleRoute();
  }

  @override
  void dispose() {
    _notShownTimeout?.cancel();
    _intro.dispose();
    _idle.dispose();
    _exit.dispose();
    super.dispose();
  }

  // Fonts were requested in main() (warmUpSplashFonts) and aren't needed until the
  // letters rise, 820ms in.
  Future<void> _start() async {
    if (_reduceMotion) {
      _intro.value = 1;
      _exit.duration = const Duration(milliseconds: 250);
      _maybeExit();
      return;
    }
    // Start the clock once the splash is really on screen, not at this first build:
    // on a slow start the drop would otherwise play behind the native launch screen.
    // The timeout only guards against never hearing that it is.
    final shown = Completer<void>();
    void onShown([Object? _]) {
      if (!shown.isCompleted) shown.complete();
    }

    _notShownTimeout = Timer(const Duration(seconds: 8), onShown);
    (widget.shown ?? firstFrameShown()).then(onShown, onError: onShown);
    await shown.future;
    _notShownTimeout?.cancel();
    if (!mounted) return;
    await _intro.forward();
    _maybeExit();
  }

  Future<void> _settleRoute() async {
    await Future<void>.delayed(_routeSettle);
    if (!mounted) return;
    _routeSettled = true;
    _maybeExit();
  }

  void _maybeExit() {
    if (!mounted || !_intro.isCompleted || _exit.isAnimating || _exit.isCompleted) return;
    if (!_routeSettled) {
      if (!_reduceMotion && !_idle.isAnimating) _idle.repeat();
      return;
    }
    _idle.stop();
    _exitHole = _holeCenter();
    _exit.forward().whenComplete(() {
      if (mounted) setState(() => _gone = true);
    });
  }

  /// The centre of the hole in the pin, in the splash's own coordinates.
  Offset? _holeCenter() {
    final pin = _pinKey.currentContext?.findRenderObject() as RenderBox?;
    final stage = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    if (pin == null || stage == null || !pin.hasSize) return null;
    return pin.localToGlobal(_pin.hole, ancestor: stage);
  }

  @override
  Widget build(BuildContext context) {
    // The app stays first and in place, so removing the splash never rebuilds it.
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (!_gone) _splash(context),
      ],
    );
  }

  Widget _splash(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    _pin = _PinGeometry((size.shortestSide * 0.17).clamp(48.0, 80.0));
    final word = _wordStyle(_pin.fontSize);

    final stage = ColoredBox(
      key: _stageKey,
      color: AppColors.cream,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PlacesPainter(_intro, _holeCenter)),
          Align(
            alignment: const Alignment(0, -0.06),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    for (var i = 0; i < 5; i++)
                      _RisingLetter('khojl'[i], word, _intro, startMs: 820.0 + 70 * i),
                    SizedBox(width: _pin.gap),
                    // The pin box sits on the baseline; the painter lets its tip
                    // hang below, as in the logo.
                    Baseline(
                      baseline: _pin.h,
                      baselineType: TextBaseline.alphabetic,
                      child: CustomPaint(
                        key: _pinKey,
                        size: Size(_pin.w, _pin.h),
                        painter: _PinPainter(_pin, _intro, _idle, _exit),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: _pin.fontSize * 0.62),
                _Tagline(_intro),
              ],
            ),
          ),
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _exit,
            child: stage,
            builder: (context, stage) {
              final t = _exit.value;
              if (t == 0) return stage!;
              final hole = _exitHole;
              if (_reduceMotion || hole == null) {
                return IgnorePointer(child: Opacity(opacity: 1 - t, child: stage));
              }
              // Fly through the pin: zoom into its hole, which looks onto the app,
              // until the hole covers the screen. Exponential, so the flight feels
              // steady; the pin's rim frames the opening all the way.
              final far = [
                Offset.zero,
                Offset(size.width, 0),
                Offset(0, size.height),
                Offset(size.width, size.height),
              ].map((c) => (c - hole).distance).reduce(math.max);
              final zoom = math.pow(far / _pin.holeR, Curves.easeInOutCubic.transform(t)).toDouble();
              return IgnorePointer(
                child: ClipPath(
                  // a touch wider than the painted hole, which may be mid-breath
                  clipper: _HoleClipper(hole, _pin.holeR * zoom * 1.04),
                  child: Transform(
                    transform: Matrix4.diagonal3Values(zoom, zoom, 1)
                      ..setTranslationRaw(hole.dx * (1 - zoom), hole.dy * (1 - zoom), 0),
                    child: stage,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Starts downloading the splash's fonts (call before runApp), so they're in by the
/// time the letters rise.
void warmUpSplashFonts() {
  _wordStyle(56);
  _taglineStyle;
}

TextStyle _wordStyle(double size) => AppType.serif(
    size: size, weight: FontWeight.w600, height: 1.0, letterSpacing: -size * 0.01);

final _taglineStyle =
    AppType.mono(size: 11, weight: FontWeight.w500, letterSpacing: 3.2, color: AppColors.inkA(0.55));

/// Progress of `t` through the window [from, to] (all in ms), clamped to 0–1.
double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// The logo's pin, sized against the wordmark (proportions measured from the app icon).
class _PinGeometry {
  _PinGeometry(this.fontSize)
      : w = fontSize * 0.59,
        h = fontSize * 0.86,
        tipBelow = fontSize * 0.17,
        gap = fontSize * 0.08;

  final double fontSize;
  final double w, h;

  /// How far the tip hangs below the baseline.
  final double tipBelow;

  /// Space between the "l" and the pin.
  final double gap;

  double get r => w / 2;
  double get holeR => r * 0.38;

  /// The hole's centre in the pin box, at rest.
  Offset get hole => Offset(w / 2, r + tipBelow);

  /// Where the tip touches down, in the pin box.
  Offset get ground => Offset(w / 2, h + tipBelow);

  /// The teardrop with its hole cut out, drawn with its top at y = 0.
  Path path() {
    final c = Offset(w / 2, r);
    final tip = Offset(w / 2, h);
    // The sides run from the tip to where they touch the circle.
    final phi = math.acos(r / (h - r));
    final right = c + Offset.fromDirection(math.pi / 2 - phi, r);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(right.dx, right.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), math.pi / 2 - phi,
          -(2 * math.pi - 2 * phi), false)
      ..close()
      ..addOval(Rect.fromCircle(center: c, radius: holeR));
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.g, this.intro, this.idle, this.exit)
      : super(repaint: Listenable.merge([intro, idle, exit]));

  final _PinGeometry g;
  final Animation<double> intro, idle, exit;

  @override
  void paint(Canvas canvas, Size size) {
    final t = intro.value * _introMs;
    final ground = g.ground;

    // Falls in from above, accelerating, and lands at 520ms.
    final fall = _span(t, 100, 520);
    if (fall == 0) return;
    final dy = (1 - Curves.easeInCubic.transform(fall)) * -g.h * 2.6;

    // Its shadow firms up as it nears the ground.
    final s = Curves.easeOut.transform(fall);
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: g.w * (0.25 + 0.4 * s), height: g.w * (0.06 + 0.09 * s)),
      Paint()
        ..color = AppColors.inkA(0.16 * s)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Two rings ripple out across the ground on impact…
    for (var i = 0; i < 2; i++) {
      final p = _span(t, 520 + i * 170.0, 1270 + i * 170.0);
      if (p > 0 && p < 1) _ring(canvas, ground, p, 1);
    }
    // …and one per breath while the session is still loading.
    final breath = idle.value;
    if (breath > 0) _ring(canvas, ground, breath, 0.7 * (1 - exit.value));

    // Landing: a damped squash-and-stretch about the tip.
    final land = _span(t, 520, 900);
    final wobble = math.sin(2 * math.pi * land) * (1 - land);
    final scaleY = 1 - 0.14 * wobble;
    final scaleX = 1 + 0.08 * wobble;
    final breathe = 1 + 0.035 * math.sin(2 * math.pi * breath);

    canvas.save();
    canvas.translate(0, g.tipBelow + dy);
    canvas
      ..translate(g.w / 2, g.h)
      ..scale(scaleX, scaleY)
      ..translate(-g.w / 2, -g.h);
    // Breathe about the hole, so the hole stays put for the exit.
    final c = Offset(g.w / 2, g.r);
    canvas
      ..translate(c.dx, c.dy)
      ..scale(breathe)
      ..translate(-c.dx, -c.dy);

    final opacity = _span(t, 100, 260);
    canvas.drawPath(
      g.path(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(g.w * 0.2, 0),
          Offset(g.w * 0.65, g.h),
          [
            AppColors.gold.withValues(alpha: opacity),
            AppColors.emerald.withValues(alpha: opacity),
          ],
        ),
    );
    canvas.restore();
  }

  void _ring(Canvas canvas, Offset at, double p, double strength) {
    final rx = g.w * (0.35 + 1.4 * p);
    canvas.drawOval(
      Rect.fromCenter(center: at, width: rx * 2, height: rx * 0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = AppColors.emerald.withValues(alpha: 0.5 * strength * math.pow(1 - p, 1.4)),
    );
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.g.fontSize != g.fontSize;
}

class _Place {
  const _Place(this.at, this.radius, this.color, this.delay);

  /// Position as a fraction of the screen.
  final Offset at;
  final double radius;
  final Color color;

  /// 0–1: when it appears, and gathers, relative to the others.
  final double delay;
}

/// Gold (and a few emerald) points of light: the places around you. They twinkle in
/// while the pin falls, then drift into it once it has landed.
class _PlacesPainter extends CustomPainter {
  _PlacesPainter(this.intro, this.target) : super(repaint: intro);

  final Animation<double> intro;
  final Offset? Function() target;

  static final List<_Place> _places = () {
    final rnd = math.Random(11);
    final out = <_Place>[];
    while (out.length < 18) {
      final at = Offset(0.06 + rnd.nextDouble() * 0.88, 0.14 + rnd.nextDouble() * 0.72);
      if ((at.dy - 0.47).abs() < 0.11) continue; // keep the wordmark's band clear
      out.add(_Place(
        at,
        1.6 + rnd.nextDouble() * 2,
        rnd.nextDouble() < 0.75 ? AppColors.gold : AppColors.emerald,
        rnd.nextDouble(),
      ));
    }
    return out;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = intro.value * _introMs;
    if (t == 0 || t > 1600) return;
    final to = target();
    if (to == null) return;
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final dot = Paint();
    for (final p in _places) {
      final appear = _span(t, 150 + p.delay * 450, 450 + p.delay * 450);
      if (appear == 0) continue;
      final gather = Curves.easeInCubic.transform(_span(t, 800 + p.delay * 200, 1350 + p.delay * 200));
      final from = Offset(p.at.dx * size.width, p.at.dy * size.height);
      final at = Offset.lerp(from, to, gather)!;
      final r = p.radius * Curves.easeOutBack.transform(appear) * (1 - 0.5 * gather);
      final alpha = 0.75 * appear * (1 - Curves.easeIn.transform(gather));
      if (alpha <= 0) continue;
      canvas.drawCircle(at, r * 2.6, glow..color = p.color.withValues(alpha: alpha * 0.35));
      canvas.drawCircle(at, r, dot..color = p.color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_PlacesPainter old) => false;
}

/// One letter of the wordmark, rising from the baseline out of a soft blur.
class _RisingLetter extends StatelessWidget {
  const _RisingLetter(this.letter, this.style, this.intro, {required this.startMs});

  final String letter;
  final TextStyle style;
  final Animation<double> intro;
  final double startMs;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      child: Text(letter, style: style),
      builder: (context, child) {
        final p = Curves.easeOutCubic.transform(
            _span(intro.value * _introMs, startMs, startMs + 480));
        final blur = (1 - p) * 5;
        return Opacity(
          opacity: p,
          child: ImageFiltered(
            enabled: blur > 0.05,
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Transform.translate(
              offset: Offset(0, (1 - p) * style.fontSize! * 0.42),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline(this.intro);

  final Animation<double> intro;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: intro,
      child: Text(splashTagline, style: _taglineStyle),
      builder: (context, child) {
        final p = Curves.easeOutCubic.transform(_span(intro.value * _introMs, 1400, 1850));
        return Opacity(
          opacity: p,
          child: Transform.translate(offset: Offset(0, (1 - p) * 8), child: child),
        );
      },
    );
  }
}

/// Everything except a circle: the splash with a hole the app shows through.
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper(this.center, this.radius);

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_HoleClipper old) => old.center != center || old.radius != radius;
}
