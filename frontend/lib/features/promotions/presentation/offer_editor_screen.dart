import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_providers.dart';
import '../data/promotions_repository.dart';
import '../promotions_providers.dart';
import 'widgets/editor_parts.dart';
import 'widgets/promo_widgets.dart';

/// Opens the offer editor; resolves to true when the offer was saved.
Future<bool> openOfferEditor(BuildContext context, {required int businessId, Offer? existing}) async {
  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => OfferEditorScreen(businessId: businessId, existing: existing),
  ));
  return saved ?? false;
}

/// The badge text the server will build, previewed while typing.
String previewDealLabel(DealType type, double? value, String text) => switch (type) {
      DealType.percentOff when value != null && value > 0 =>
        '${value == value.roundToDouble() ? value.toInt() : value}% OFF',
      DealType.amountOff when value != null && value > 0 => 'Rs ${_thousands(value.toInt())} OFF',
      DealType.bogo => 'BUY 1 GET 1',
      DealType.freeItem when text.trim().isNotEmpty => 'FREE ${text.trim().toUpperCase()}',
      DealType.other when text.trim().isNotEmpty => text.trim(),
      _ => 'SPECIAL OFFER',
    };

String _thousands(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// Create or edit a special offer (SRS UC-11; SDD Algorithm 6).
class OfferEditorScreen extends ConsumerStatefulWidget {
  const OfferEditorScreen({super.key, required this.businessId, this.existing});
  final int businessId;
  final Offer? existing;

  @override
  ConsumerState<OfferEditorScreen> createState() => _OfferEditorScreenState();
}

class _OfferEditorScreenState extends ConsumerState<OfferEditorScreen> {
  late final Offer? _o = widget.existing;
  late final _title = TextEditingController(text: _o?.title ?? '');
  late final _description = TextEditingController(text: _o?.description ?? '');
  late final _value = TextEditingController(
      text: _o?.dealValue == null ? '' : _o!.dealValue!.toStringAsFixed(
          _o.dealValue! == _o.dealValue!.roundToDouble() ? 0 : 1));
  late final _text = TextEditingController(text: _o?.dealText ?? '');
  late final _terms = TextEditingController(text: _o?.terms ?? '');
  late DealType _type = _o?.dealType ?? DealType.percentOff;
  late DateTime _start = _o?.startDate ?? _today();
  late DateTime? _end = _o?.endDate ?? _today().add(const Duration(days: 14));
  late bool _hasEnd = _o == null || _o.endDate != null;
  late bool _active = _o?.isActive ?? false;
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _value, _text, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _dealValue => double.tryParse(_value.text.trim());

  /// Mirrors the server's checks so mistakes show before saving (USE-3).
  String? _problem() {
    if (_title.text.trim().isEmpty) return 'Give the offer a title.';
    if (_hasEnd && _end != null && _end!.isBefore(_start)) {
      return 'The end date can’t be before the start date.';
    }
    final v = _dealValue;
    return switch (_type) {
      DealType.percentOff when v == null || v < 1 || v > 100 =>
        'Enter a discount between 1% and 100%.',
      DealType.amountOff when v == null || v < 1 => 'Enter how many rupees off the deal gives.',
      DealType.freeItem when _text.text.trim().isEmpty => 'Say what’s free, e.g. “Dessert”.',
      DealType.other when _text.text.trim().isEmpty =>
        'Add a short label for the deal, e.g. “Student deal”.',
      _ => null,
    };
  }

  Future<void> _save() async {
    final problem = _problem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = OfferDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      dealType: _type,
      dealValue: _type == DealType.percentOff || _type == DealType.amountOff ? _dealValue : null,
      dealText: _type == DealType.freeItem || _type == DealType.other ? _text.text.trim() : '',
      startDate: _start,
      endDate: _hasEnd ? _end : null,
      terms: _terms.text.trim(),
      isActive: _active,
    );
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .saveOffer(widget.businessId, draft, offerId: _o?.id);
      ref.read(promotionChangesProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = describeApiError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final verified =
        ref.watch(ownerBusinessDetailProvider(widget.businessId)).valueOrNull?.isVerified ?? true;
    final needsValue = _type == DealType.percentOff || _type == DealType.amountOff;
    final needsText = _type == DealType.freeItem || _type == DealType.other;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: _o == null ? 'New offer' : 'Edit offer',
            subtitle: 'The deal customers get',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                Center(
                  child: DealBadge(
                    label: previewDealLabel(_type, _dealValue, _text.text),
                    size: 14,
                    shimmer: true,
                  ),
                ),
                const EditorLabel('Title'),
                EditorTextField(
                  fieldKey: const ValueKey('offer-title'),
                  controller: _title,
                  hint: 'e.g. 20% off all burgers',
                  maxLength: 200,
                  onChanged: (_) => setState(() {}),
                ),
                const EditorLabel('Deal'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in DealType.values)
                      KhojloChip(
                        label: t.label,
                        active: _type == t,
                        dense: true,
                        onTap: () => setState(() => _type = t),
                      ),
                  ],
                ),
                if (needsValue) ...[
                  const SizedBox(height: 10),
                  EditorTextField(
                    fieldKey: const ValueKey('offer-value'),
                    controller: _value,
                    hint: _type == DealType.percentOff ? 'Percent off, e.g. 20' : 'Rupees off, e.g. 500',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                if (needsText) ...[
                  const SizedBox(height: 10),
                  EditorTextField(
                    fieldKey: const ValueKey('offer-text'),
                    controller: _text,
                    hint: _type == DealType.freeItem ? 'What’s free? e.g. Dessert' : 'Short label, e.g. Student deal',
                    maxLength: 40,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                const EditorLabel('Description', hint: 'Optional'),
                EditorTextField(
                  controller: _description,
                  hint: 'What’s included, and who it’s for',
                  maxLength: 1000,
                  maxLines: 4,
                ),
                const EditorLabel('Dates'),
                DateField(
                  label: 'STARTS',
                  value: _start,
                  onPicked: (d) => setState(() => _start = d),
                ),
                SwitchRow(
                  title: 'Has an end date',
                  subtitle: _hasEnd ? null : 'Runs until you deactivate it.',
                  value: _hasEnd,
                  onChanged: (v) => setState(() {
                    _hasEnd = v;
                    _end ??= _start.add(const Duration(days: 14));
                  }),
                ),
                if (_hasEnd)
                  DateField(
                    label: 'ENDS',
                    value: _end,
                    first: _start,
                    onPicked: (d) => setState(() => _end = d),
                  ),
                const EditorLabel('Terms & conditions', hint: 'Optional'),
                EditorTextField(
                  controller: _terms,
                  hint: 'e.g. Dine-in only. One per customer.',
                  maxLength: 2000,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SwitchRow(
                  title: 'Active',
                  subtitle: !verified
                      ? 'Offers can be activated once Khojlo verifies your business. It’s '
                          'saved as a draft until then.'
                      : _active
                          ? (_start.isAfter(_today())
                              ? 'Scheduled: it goes live on ${shortDate(_start)}.'
                              : 'Customers see it on your profile now.')
                          : 'Saved as a draft; customers don’t see it.',
                  value: _active && verified,
                  onChanged: verified ? (v) => setState(() => _active = v) : null,
                ),
                if (_error != null) FormError(_error!),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: _o == null ? 'Save offer' : 'Save changes',
                  tone: ButtonTone.emerald,
                  loading: _saving,
                  onTap: _saving
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _save();
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
