import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/saved.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../account_providers.dart';

/// Module 1 — Pinterest-style saved collections.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedListsProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopBar(title: 'Saved', onBack: () => context.pop()),
          Expanded(
            child: saved.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (_, __) => Center(
                  child: Text('Couldn’t load your collections',
                      style: AppType.sans(color: AppColors.inkA(0.6)))),
              data: (lists) => lists.isEmpty
                  ? _empty()
                  : RefreshIndicator(
                      color: AppColors.emerald,
                      onRefresh: () async =>
                          ref.refresh(savedListsProvider.future),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
                        children: [
                          Text('COLLECTIONS', style: AppType.label()),
                          const SizedBox(height: 14),
                          GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 1.5,
                            children: [
                              for (final l in lists) _CollectionCard(list: l),
                            ],
                          ),
                          const SizedBox(height: 28),
                          Text('ALL SAVED', style: AppType.label()),
                          const SizedBox(height: 8),
                          for (final l in lists)
                            for (var i = 0; i < l.businesses.length; i++)
                              BusinessListRow(
                                business: l.businesses[i],
                                showDivider: !(i == 0),
                                onTap: () => context.push(
                                    '/business/${l.businesses[i].id}'),
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

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border_rounded,
                size: 40, color: AppColors.inkA(0.3)),
            const SizedBox(height: 14),
            Text('Nothing saved yet', style: AppType.serif(size: 20)),
            const SizedBox(height: 8),
            Text('Tap the heart on a place to start a collection.',
                style: AppType.sans(size: 13, color: AppColors.inkA(0.5))),
          ],
        ),
      );
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.list});
  final SavedList list;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientFor(list.tone),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bookmark_rounded, color: AppColors.whiteA(0.85), size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(list.name, style: AppType.serif(size: 18, color: Colors.white)),
              const SizedBox(height: 2),
              Text('${list.count} places',
                  style: AppType.mono(size: 11, color: AppColors.whiteA(0.8))),
            ],
          ),
        ],
      ),
    );
  }
}
