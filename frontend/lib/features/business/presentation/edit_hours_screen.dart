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

/// Owner screen: weekly opening hours (dashboard → "Operating hours"). Hours power
/// the "Open now" search filter and the open/closed labels.
class EditHoursScreen extends ConsumerWidget {
  const EditHoursScreen({super.key, required this.businessId});
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownerBusinessDetailProvider(businessId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: async.when(
        loading: () => const OwnerFormSkeleton(title: 'Opening hours'),
        error: (e, _) => OwnerLoadError(
          title: 'Opening hours',
          message: describeApiError(e),
          onRetry: () => ref.invalidate(ownerBusinessDetailProvider(businessId)),
        ),
        data: (b) => _HoursForm(business: b),
      ),
    );
  }
}

class _HoursForm extends ConsumerStatefulWidget {
  const _HoursForm({required this.business});
  final BusinessDetail business;

  @override
  ConsumerState<_HoursForm> createState() => _HoursFormState();
}

class _HoursFormState extends ConsumerState<_HoursForm> {
  late List<OpeningHours> _hours = normalizeWeek(widget.business.hours);
  late bool _listHours = widget.business.hours.isNotEmpty;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = widget.business.id;
    try {
      await ref
          .read(businessRepositoryProvider)
          .replaceHours(id, _listHours ? _hours : const []);
      ref.invalidate(ownerBusinessDetailProvider(id));
      ref.invalidate(businessDetailProvider(id));
      ref.invalidate(myBusinessesProvider);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text('Opening hours saved',
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
          title: 'Opening hours',
          subtitle: widget.business.name,
          onBack: () => context.pop(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              Text(
                'Shoppers can filter for places that are open right now, and every '
                'listing shows whether you’re open today.',
                style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.55)),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text('List my opening hours',
                        style: AppType.sans(size: 14, weight: FontWeight.w600)),
                  ),
                  KhojloToggle(
                    value: _listHours,
                    onChanged: (v) => setState(() => _listHours = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_listHours)
                HoursEditor(hours: _hours, onChanged: (h) => setState(() => _hours = h))
              else
                Text(
                  'Your listing won’t show opening hours, and it won’t appear when '
                  'shoppers filter for places open now.',
                  style: AppType.sans(size: 13, color: AppColors.inkA(0.55)),
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
              label: 'Save hours',
              tone: ButtonTone.emerald,
              loading: _saving,
              onTap: _save,
            ),
          ),
        ),
      ],
    );
  }
}
