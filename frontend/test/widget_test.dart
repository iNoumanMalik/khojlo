import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/theme/app_colors.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/widgets/widgets.dart';

void main() {
  testWidgets('PrimaryButton renders its label and responds to tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: PrimaryButton(
              label: 'Get started',
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Get started'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    expect(tapped, isTrue);
  });

  test('color tokens match the design bundle', () {
    expect(AppColors.emerald, const Color(0xFF1D6D5A));
    expect(AppColors.gold, const Color(0xFFE3A73D));
    expect(AppColors.cream, const Color(0xFFFBF6EE));
  });
}
