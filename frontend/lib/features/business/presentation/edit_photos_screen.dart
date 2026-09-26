import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/business.dart';
import '../../../core/models/photo.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../discovery/discovery_providers.dart';
import '../business_providers.dart';
import '../data/business_repository.dart';
import 'widgets/owner_screen_states.dart';
import 'widgets/photo_manager.dart';

/// Owner screen: the cover photo and gallery (dashboard → "Photos").
class EditPhotosScreen extends ConsumerWidget {
  const EditPhotosScreen({super.key, required this.businessId});
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerBusinessDetailProvider(businessId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: async.when(
        loading: () => const OwnerFormSkeleton(title: 'Photos'),
        error: (e, _) => OwnerLoadError(
          title: 'Photos',
          message: describeApiError(e),
          onRetry: () => ref.invalidate(ownerBusinessDetailProvider(businessId)),
        ),
        data: (b) => _PhotosForm(business: b),
      ),
    );
  }
}

class _PhotosForm extends ConsumerStatefulWidget {
  const _PhotosForm({required this.business});
  final BusinessDetail business;

  @override
  ConsumerState<_PhotosForm> createState() => _PhotosFormState();
}

class _PhotosFormState extends ConsumerState<_PhotosForm> {
  late List<Photo> _photos = widget.business.photos;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = widget.business.id;
    try {
      await ref.read(businessRepositoryProvider).replacePhotos(id, _photos);
      ref.invalidate(ownerBusinessDetailProvider(id));
      ref.invalidate(businessDetailProvider(id));
      ref.invalidate(myBusinessesProvider);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text('Photos saved', style: AppType.sans(size: 13, color: Colors.white)),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopBar(
          title: 'Photos',
          subtitle: widget.business.name,
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              Text(
                'Your cover appears on every card in the feed and search. The rest '
                'show in the gallery on your page. With no photos, your colour is used.',
                style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.55)),
              ),
              const SizedBox(height: 18),
              PhotoManager(
                initial: widget.business.photos,
                tone: widget.business.tone,
                onChanged: (photos, uploading) => setState(() {
                  _photos = photos;
                  _uploading = uploading;
                }),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Text(_error!, style: AppType.sans(size: 12.5, color: AppColors.plum)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
            child: PrimaryButton(
              label: _uploading ? 'Uploading…' : 'Save photos',
              tone: ButtonTone.emerald,
              loading: _saving,
              onTap: _uploading ? null : _save,
            ),
          ),
        ),
      ],
    );
  }
}
