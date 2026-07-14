import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import 'mock_data.dart';

/// Module 6 — spatial exploration (prototype). Matches the design's stylized
/// abstract map with glowing pins + a snap carousel.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  static const _pins = [
    (x: 0.26, y: 0.22, big: false),
    (x: 0.62, y: 0.15, big: false),
    (x: 0.47, y: 0.34, big: true),
    (x: 0.20, y: 0.52, big: false),
    (x: 0.74, y: 0.46, big: false),
    (x: 0.55, y: 0.62, big: false),
    (x: 0.33, y: 0.72, big: false),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _MapPainter())),
          for (final p in _pins)
            Align(
              alignment: Alignment(p.x * 2 - 1, p.y * 2 - 1),
              child: _Pin(big: p.big),
            ),
          // search + filter
          Positioned(
            top: 60,
            left: 22,
            right: 22,
            child: Row(
              children: [
                const Expanded(child: SearchPill(text: 'Search this area...')),
                const SizedBox(width: 10),
                GlassIconButton(icon: Icons.tune_rounded, size: 44, onTap: () {}),
              ],
            ),
          ),
          // snap carousel
          Positioned(
            left: 0,
            right: 0,
            bottom: 96,
            child: SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: Mock.places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) {
                  final b = Mock.places[i];
                  return GestureDetector(
                    onTap: () => context.push('/business/${b.id}'),
                    child: SizedBox(
                      width: 220,
                      child: GlassSurface(
                        radius: 22,
                        opacity: 0.85,
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              height: 70,
                              child: ImageTile(tone: b.tone, radius: 14),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(b.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.serif(size: 15)),
                                  const SizedBox(height: 6),
                                  Text('${b.distanceLabel} · Open now',
                                      style: AppType.mono(
                                          size: 10.5,
                                          color: AppColors.emerald)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.big});
  final bool big;

  @override
  Widget build(BuildContext context) {
    final color = big ? AppColors.emerald : AppColors.gold;
    return Container(
      width: big ? 26 : 16,
      height: big ? 26 : 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 3),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEFE9DC));
    // faint blobs
    canvas.drawCircle(
      Offset(size.width * 0.3, size.height * 0.2),
      size.width * 0.5,
      Paint()..color = AppColors.emerald.withValues(alpha: 0.06),
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      size.width * 0.5,
      Paint()..color = AppColors.gold.withValues(alpha: 0.06),
    );
    // roads
    final road = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final p1 = Path()
      ..moveTo(-10, size.height * 0.3)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.1,
          size.width * 0.5, size.height * 0.35)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.6,
          size.width + 10, size.height * 0.25);
    final p2 = Path()
      ..moveTo(size.width * 0.15, -10)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.5,
          size.width * 0.1, size.height + 10);
    final p3 = Path()
      ..moveTo(size.width * 0.7, -10)
      ..quadraticBezierTo(size.width * 0.6, size.height * 0.5,
          size.width * 0.85, size.height + 10);
    for (final p in [p1, p2, p3]) {
      canvas.drawPath(p, road);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
