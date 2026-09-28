import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/chat_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';

/// Hosts the five primary tabs with the floating glass dock overlaid, plus a
/// "Surprise Me" shuffle FAB on the Home tab.
class ShellScaffold extends ConsumerWidget {
  const ShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// The Chat tab's position in the dock.
  static const chatTab = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      body: navigationShell,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: index == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 78),
              child: GestureDetector(
                onTap: () => context.push('/surprise'),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      colors: [Color(0xFFF3C365), AppColors.gold],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.shuffle_rounded, color: Colors.white),
                ),
              ),
            )
          : null,
      bottomNavigationBar: FloatingTabBar(
        currentIndex: index,
        badges: {chatTab: ref.watch(unreadMessagesProvider)},
        onTap: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
