import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/features/search/presentation/search_screen.dart';

import 'search_screens_test.dart' as s;

void main() {
  testWidgets(
    'compare: selecting and unselecting a result never throws mid-animation',
    (tester) async {
      final repo = s.FakeSearchRepository();
      final container = s.makeContainer(repo);
      addTearDown(container.dispose);
      await s.pumpScreen(tester, container, const SearchScreen());
      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));
      // dismiss suggestions like a user pressing search
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump(const Duration(milliseconds: 600));
      final circle = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label == 'Add to compare' ||
                w.properties.label == 'Remove from compare'),
      );
      for (var round = 0; round < 2; round++) {
        await tester.tap(circle.first);
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          final e = tester.takeException();
          if (e != null) fail('round $round frame $i: $e');
        }
      }
    },
  );
}
