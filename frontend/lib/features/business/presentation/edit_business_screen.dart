import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/business.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../discovery/discovery_providers.dart';
import '../business_providers.dart';
import '../data/business_repository.dart';
import 'widgets/business_form_fields.dart';
import 'widgets/owner_screen_states.dart';

/// Owner screen: edit profile basics, price range and map pin (dashboard →
/// "Edit business profile").
class EditBusinessScreen extends ConsumerWidget {
  const EditBusinessScreen({super.key, required this.businessId});
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerBusinessDetailProvider(businessId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: async.when(
        loading: () => const OwnerFormSkeleton(title: 'Edit business'),
        error: (e, _) => OwnerLoadError(
          title: 'Edit business',
          message: describeApiError(e),
          onRetry: () => ref.invalidate(ownerBusinessDetailProvider(businessId)),
        ),
        data: (b) => _EditBusinessForm(business: b),
      ),
    );
  }
}

class _EditBusinessForm extends ConsumerStatefulWidget {
  const _EditBusinessForm({required this.business});
  final BusinessDetail business;

  @override
  ConsumerState<_EditBusinessForm> createState() => _EditBusinessFormState();
}

class _EditBusinessFormState extends ConsumerState<_EditBusinessForm> {
  late final _name = TextEditingController(text: widget.business.name);
  late final _tagline = TextEditingController(text: widget.business.tagline);
  late final _description = TextEditingController(text: widget.business.description);
  late final _address = TextEditingController(text: widget.business.address);
  late final _priceMin =
      TextEditingController(text: widget.business.priceMin?.toString() ?? '');
  late final _priceMax =
      TextEditingController(text: widget.business.priceMax?.toString() ?? '');
  late String _tier = widget.business.priceLevel;
  late double? _latitude = widget.business.latitude;
  late double? _longitude = widget.business.longitude;
  bool _saving = false;
  String? _error;

  String? get _priceError => PriceRangeFields.validate(
      PriceRangeFields.parse(_priceMin), PriceRangeFields.parse(_priceMax));

  @override
  void dispose() {
    for (final c in [_name, _tagline, _description, _address, _priceMin, _priceMax]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Your business needs a name.');
      return;
    }
    if (_priceError != null) {
      setState(() => _error = _priceError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = widget.business.id;
    try {
      await ref.read(businessRepositoryProvider).update(id, {
        'name': _name.text.trim(),
        'tagline': _tagline.text.trim(),
        'description': _description.text.trim(),
        'address': _address.text.trim(),
        'price_level': _tier,
        'price_min': PriceRangeFields.parse(_priceMin),
        'price_max': PriceRangeFields.parse(_priceMax),
        'latitude': _latitude,
        'longitude': _longitude,
      });
      ref.invalidate(ownerBusinessDetailProvider(id));
      ref.invalidate(businessDetailProvider(id));
      ref.invalidate(myBusinessesProvider);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text('Business profile saved',
              style: AppType.sans(size: 13, color: Colors.white)),
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
          title: 'Edit business',
          subtitle: widget.business.name,
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              AppField(label: 'Business name', controller: _name),
              const SizedBox(height: 16),
              AppField(label: 'Tagline', controller: _tagline),
              const SizedBox(height: 16),
              AppField(label: 'Description', controller: _description, maxLines: 4),
              const SizedBox(height: 16),
              AppField(label: 'Address', controller: _address, hint: 'Street, area, city'),
              const SizedBox(height: 12),
              LocationPinField(
                latitude: _latitude,
                longitude: _longitude,
                onChanged: (lat, lng) => setState(() {
                  _latitude = lat;
                  _longitude = lng;
                }),
              ),
              const SizedBox(height: 24),
              Text('PRICE LEVEL', style: AppType.label()),
              const SizedBox(height: 10),
              PriceTierSelector(value: _tier, onChanged: (t) => setState(() => _tier = t)),
              const SizedBox(height: 20),
              Text('TYPICAL PRICES · OPTIONAL', style: AppType.label()),
              const SizedBox(height: 12),
              PriceRangeFields(
                minController: _priceMin,
                maxController: _priceMax,
                onChanged: () => setState(() {}),
                error: _priceError,
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
              label: 'Save changes',
              tone: ButtonTone.emerald,
              loading: _saving,
              onTap: _priceError == null ? _save : null,
            ),
          ),
        ),
      ],
    );
  }
}
