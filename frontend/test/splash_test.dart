import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/ui/splash_overlay.dart';

/// Stands in for the app under the splash; counts how often its state is created.
class _App extends StatefulWidget {
  const _App();

  static int created = 0;

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  @override
  void initState() {
    super.initState();
    _App.created++;
  }

  @override
  Widget build(BuildContext context) => const Text('Home', textDirection: TextDirection.ltr);
}

Future<void> _pumpSplash(WidgetTester tester, ValueNotifier<bool> ready,
    {Future<void>? shown}) {
  return tester.pumpWidget(MediaQuery(
    data: const MediaQueryData(size: Size(390, 844)),
    child: ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (_, isReady, __) => SplashOverlay(
          ready: isReady, shown: shown ?? Future.value(), child: const _App()),
    ),
  ));
}

double _taglineOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.ancestor(of: find.text(splashTagline), matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  setUp(() => _App.created = 0);

  testWidgets('plays the intro, then reveals the app without rebuilding it', (tester) async {
    final ready = ValueNotifier(true);
    await _pumpSplash(tester, ready);
    expect(find.text(splashTagline), findsOneWidget);
    expect(find.text('Home'), findsOneWidget); // already in place underneath

    await tester.pump(); // on screen
    await tester.pump(const Duration(milliseconds: 2200)); // intro
    expect(find.text(splashTagline), findsOneWidget);
    await tester.pump(); // exit starts
    await tester.pump(const Duration(milliseconds: 900)); // exit
    await tester.pump();

    expect(find.text(splashTagline), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(_App.created, 1);
  });

  testWidgets('holds on the pin until the session is known', (tester) async {
    final ready = ValueNotifier(false);
    await _pumpSplash(tester, ready);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text(splashTagline), findsOneWidget);

    ready.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // route settles
    await tester.pump(const Duration(milliseconds: 900)); // exit
    await tester.pump();
    expect(find.text(splashTagline), findsNothing);
    expect(_App.created, 1);
  });

  testWidgets('starts the intro only once the splash is on screen', (tester) async {
    // On a slow Android start the native launch screen covers the first frames.
    final shown = Completer<void>();
    await _pumpSplash(tester, ValueNotifier(true), shown: shown.future);
    await tester.pump(const Duration(seconds: 3));
    expect(_taglineOpacity(tester), 0); // still waiting: nothing has played unseen

    shown.complete();
    await tester.pump(); // the intro starts…
    await tester.pump(); // …and its clock with this frame
    await tester.pump(const Duration(milliseconds: 1000));
    expect(_taglineOpacity(tester), 0); // the tagline comes in at 1.4s…
    await tester.pump(const Duration(milliseconds: 900));
    expect(_taglineOpacity(tester), 1); // …and is in by 1.85s
  });

  testWidgets('plays anyway if the splash is never reported on screen', (tester) async {
    await _pumpSplash(tester, ValueNotifier(true), shown: Completer<void>().future);
    await tester.pump(const Duration(seconds: 8)); // the safety timeout
    await tester.pump(const Duration(milliseconds: 2200)); // intro
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900)); // exit
    await tester.pump();
    expect(find.text(splashTagline), findsNothing);
  });

  testWidgets('with reduced motion it skips the animation and just fades', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(size: Size(390, 844), disableAnimations: true),
      child: SplashOverlay(ready: true, child: const _App()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(find.text(splashTagline), findsNothing);
  });
}
