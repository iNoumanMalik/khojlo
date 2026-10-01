import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/media/photo_source.dart';
import '../../../core/models/business.dart';
import '../../../core/models/campaign.dart';
import '../../../core/models/photo.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_providers.dart';
import '../data/promotions_repository.dart';
import '../promotions_providers.dart';
import 'widgets/editor_parts.dart';
import 'widgets/promo_widgets.dart';

/// Opens the campaign editor; resolves to true when it was saved.
Future<bool> openCampaignEditor(BuildContext context,
    {required int businessId, Campaign? existing}) async {
  final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => CampaignEditorScreen(businessId: businessId, existing: existing),
  ));
  return saved ?? false;
}

/// Create or edit a promotional campaign: information, promotion content (linked offers,
/// featured services, terms) and visibility (publish, notify savers).
class CampaignEditorScreen extends ConsumerStatefulWidget {
  const CampaignEditorScreen({super.key, required this.businessId, this.existing});
  final int businessId;
  final Campaign? existing;

  @override
  ConsumerState<CampaignEditorScreen> createState() => _CampaignEditorScreenState();
}

class _CampaignEditorScreenState extends ConsumerState<CampaignEditorScreen> {
  late final Campaign? _c = widget.existing;
  late final _name = TextEditingController(text: _c?.name ?? '');
  late final _message = TextEditingController(text: _c?.message ?? '');
  late final _description = TextEditingController(text: _c?.description ?? '');
  late final _terms = TextEditingController(text: _c?.terms ?? '');
  late DateTime _start = _c?.startDate ?? _today();
  late DateTime _end = _c?.endDate ?? _today().add(const Duration(days: 7));
  late final Set<int> _offerIds = {...?_c?.offers.map((o) => o.id)};
  late final Set<int> _serviceIds = {...?_c?.services.map((s) => s.id)};
  late bool _published = _c?.isPublished ?? false;
  late bool _notify = _c?.notifySavers ?? false;
  late Photo? _banner = _c?.banner;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    for (final c in [_name, _message, _description, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickBanner() async {
    final picked = await ref.read(photoSourceProvider).pickOne();
    if (picked == null || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final photo = await ref
          .read(mediaRepositoryProvider)
          .upload(picked.bytes, filename: picked.name);
      if (mounted) setState(() => _banner = photo);
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String? _problem(List<Offer> offers) {
    if (_name.text.trim().isEmpty) return 'Give the campaign a name.';
    if (_end.isBefore(_start)) return 'The end date can’t be before the start date.';
    if (_published) {
      final usable = offers.where((o) =>
          _offerIds.contains(o.id) &&
          (o.status == PromoStatus.active || o.status == PromoStatus.scheduled));
      if (usable.isEmpty) {
        return 'Link at least one active or scheduled offer first. A campaign promotes '
            'your offers.';
      }
    }
    return null;
  }

  Future<void> _save(List<Offer> offers) async {
    final problem = _problem(offers);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final draft = CampaignDraft(
      name: _name.text.trim(),
      message: _message.text.trim(),
      description: _description.text.trim(),
      bannerKey: _banner?.key,
      startDate: _start,
      endDate: _end,
      terms: _terms.text.trim(),
      // Keep the order the offers appear in.
      offerIds: [for (final o in offers) if (_offerIds.contains(o.id)) o.id],
      serviceIds: _serviceIds.toList(),
      isPublished: _published,
      notifySavers: _notify,
    );
    try {
      await ref
          .read(promotionsRepositoryProvider)
          .saveCampaign(widget.businessId, draft, campaignId: _c?.id);
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
    final business = ref.watch(ownerBusinessDetailProvider(widget.businessId)).valueOrNull;
    final verified = business?.isVerified ?? true;
    final offers = ref.watch(ownerOffersProvider(widget.businessId)).valueOrNull ?? const [];
    final services = business?.services ?? const <Service>[];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: _c == null ? 'New campaign' : 'Edit campaign',
            subtitle: 'Promote one or more of your offers',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _BannerPicker(
                  banner: _banner,
                  tone: business?.tone ?? 'gold',
                  uploading: _uploading,
                  onPick: _pickBanner,
                  onRemove: () => setState(() => _banner = null),
                ),
                const EditorLabel('Campaign name'),
                EditorTextField(
                  fieldKey: const ValueKey('campaign-name'),
                  controller: _name,
                  hint: 'e.g. Weekend Food Festival',
                  maxLength: 120,
                ),
                const EditorLabel('Promotional message', hint: 'One line for the banner'),
                EditorTextField(
                  controller: _message,
                  hint: 'e.g. Special deals all weekend!',
                  maxLength: 160,
                ),
                const EditorLabel('Description', hint: 'Optional'),
                EditorTextField(
                  controller: _description,
                  hint: 'What the promotion is about',
                  maxLength: 1500,
                  maxLines: 4,
                ),
                const EditorLabel('Dates'),
                Row(
                  children: [
                    Expanded(
                      child: DateField(
                          label: 'STARTS', value: _start, onPicked: (d) => setState(() => _start = d)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DateField(
                          label: 'ENDS',
                          value: _end,
                          first: _start,
                          onPicked: (d) => setState(() => _end = d)),
                    ),
                  ],
                ),
                const EditorLabel('Offers to promote',
                    hint: 'Pick from your offers; the campaign shows the ones that are live.'),
                if (offers.isEmpty)
                  Text('You have no offers yet. Create an offer first, then link it here.',
                      style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6)))
                else
                  for (final o in offers)
                    _OfferPick(
                      offer: o,
                      selected: _offerIds.contains(o.id),
                      onChanged: o.status == PromoStatus.expired && !_offerIds.contains(o.id)
                          ? null
                          : (v) => setState(() => v ? _offerIds.add(o.id) : _offerIds.remove(o.id)),
                    ),
                if (services.isNotEmpty) ...[
                  const EditorLabel('Featured services', hint: 'Optional'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in services)
                        KhojloChip(
                          label: s.name,
                          dense: true,
                          active: _serviceIds.contains(s.id),
                          onTap: () => setState(() => _serviceIds.contains(s.id)
                              ? _serviceIds.remove(s.id)
                              : _serviceIds.add(s.id)),
                        ),
                    ],
                  ),
                ],
                const EditorLabel('Terms & conditions', hint: 'Optional'),
                EditorTextField(
                  controller: _terms,
                  hint: 'e.g. Offers can’t be combined.',
                  maxLength: 2000,
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                SwitchRow(
                  title: 'Publish',
                  subtitle: !verified
                      ? 'Campaigns can be published once Khojlo verifies your business.'
                      : _published
                          ? (_start.isAfter(_today())
                              ? 'Scheduled: its banner appears on ${shortDate(_start)}.'
                              : 'Shows as a banner on Khojlo’s home screen and a badge on your '
                                  'listing. You can run one campaign at a time.')
                          : 'Saved as a draft; customers don’t see it.',
                  value: _published && verified,
                  onChanged: verified ? (v) => setState(() => _published = v) : null,
                ),
                SwitchRow(
                  title: 'Notify people who saved my business',
                  subtitle: 'They get one notification when the campaign goes live.',
                  value: _notify,
                  onChanged: (v) => setState(() => _notify = v),
                ),
                if (_error != null) FormError(_error!),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: _c == null ? 'Save campaign' : 'Save changes',
                  tone: ButtonTone.emerald,
                  loading: _saving,
                  onTap: _saving || _uploading ? null : () => _save(offers),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPicker extends StatelessWidget {
  const _BannerPicker({
    required this.banner,
    required this.tone,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
  });
  final Photo? banner;
  final String tone;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: banner == null ? 'Add a banner image' : 'Change the banner image',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: uploading ? null : onPick,
        child: SizedBox(
          height: 150,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ImageTile(tone: tone, photo: banner, radius: 0),
                Container(color: Colors.black.withValues(alpha: banner == null ? 0.15 : 0.25)),
                Center(
                  child: uploading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(banner == null ? 'Add a banner image' : 'Change banner',
                                style: AppType.sans(
                                    size: 13, weight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                ),
                if (banner != null && !uploading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GlassIconButton(icon: Icons.close_rounded, size: 34, onTap: onRemove),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferPick extends StatelessWidget {
  const _OfferPick({required this.offer, required this.selected, required this.onChanged});
  final Offer offer;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: selected,
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? false),
      activeColor: AppColors.emerald,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(offer.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.sans(size: 13.5, weight: FontWeight.w600)),
      subtitle: Row(children: [
        PromoStatusChip(status: offer.status),
        const SizedBox(width: 6),
        Flexible(
          child: Text(offer.dealLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.mono(size: 10.5, color: AppColors.inkA(0.55))),
        ),
      ]),
    );
  }
}
