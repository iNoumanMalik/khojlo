import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/models/business.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../business_providers.dart';
import '../../data/business_repository.dart';

// ─────────────── price tier ───────────────

/// $ / $$ / $$$ picker used by registration and the edit screen.
class PriceTierSelector extends StatelessWidget {
  const PriceTierSelector({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in const ['\$', '\$\$', '\$\$\$'])
          GestureDetector(
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: value == p ? AppColors.emerald : AppColors.whiteA(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inkA(0.08)),
              ),
              child: Text(p,
                  style: AppType.mono(
                      size: 14, color: value == p ? Colors.white : AppColors.ink)),
            ),
          ),
      ],
    );
  }
}

// ─────────────── price range (PKR) ───────────────

/// "From Rs … To Rs …" fields. Both optional; validate with [validate].
class PriceRangeFields extends StatelessWidget {
  const PriceRangeFields({
    super.key,
    required this.minController,
    required this.maxController,
    this.onChanged,
    this.error,
  });

  final TextEditingController minController;
  final TextEditingController maxController;
  final VoidCallback? onChanged;
  final String? error;

  static int? parse(TextEditingController c) => int.tryParse(c.text.trim());

  /// A message when the range is inconsistent, else null.
  static String? validate(int? min, int? max) => min != null && max != null && min > max
      ? 'The “from” price can’t be higher than the “to” price.'
      : null;

  @override
  Widget build(BuildContext context) {
    final formatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(7),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppField(
                label: 'From',
                controller: minController,
                hint: '800',
                prefixText: 'Rs ',
                keyboardType: TextInputType.number,
                inputFormatters: formatters,
                onChanged: (_) => onChanged?.call(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppField(
                label: 'To',
                controller: maxController,
                hint: '2500',
                prefixText: 'Rs ',
                keyboardType: TextInputType.number,
                inputFormatters: formatters,
                onChanged: (_) => onChanged?.call(),
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(error!, style: AppType.sans(size: 12, color: AppColors.plum)),
        ],
      ],
    );
  }
}

// ─────────────── location pin ───────────────

/// "Use my current location" button, or the pinned coordinates with Update / Remove.
/// A map picker replaces this in the Maps module.
class LocationPinField extends ConsumerStatefulWidget {
  const LocationPinField({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double? latitude, double? longitude) onChanged;

  @override
  ConsumerState<LocationPinField> createState() => _LocationPinFieldState();
}

class _LocationPinFieldState extends ConsumerState<LocationPinField> {
  bool _locating = false;
  String? _error;
  bool _blocked = false;

  Future<void> _useCurrent() async {
    setState(() {
      _locating = true;
      _error = null;
      _blocked = false;
    });
    final result =
        await ref.read(locationServiceProvider).locate(prompt: true, fresh: true);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _blocked = result.status == LocationStatus.deniedForever;
      _error = switch (result.status) {
        LocationStatus.available => null,
        LocationStatus.denied =>
          'Location permission was denied. You can still continue with just the address.',
        LocationStatus.deniedForever =>
          'Location is blocked for Khojlo. Allow it in Settings, or continue with the address.',
        LocationStatus.serviceDisabled => 'Turn on location services and try again.',
        LocationStatus.unsupported =>
          'This device can’t share its location. Continue with just the address.',
        _ => 'Couldn’t get your location. Try again, or continue with the address.',
      };
    });
    final fix = result.fix;
    if (fix != null) widget.onChanged(fix.latitude, fix.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.latitude != null && widget.longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pinned)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.place_rounded, color: AppColors.emerald),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location pinned',
                          style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
                      Text(
                        '${widget.latitude!.toStringAsFixed(5)}, '
                        '${widget.longitude!.toStringAsFixed(5)}',
                        style: AppType.mono(size: 11, color: AppColors.inkA(0.55)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _locating ? null : _useCurrent,
                  child: Text(_locating ? '…' : 'Update',
                      style: AppType.sans(
                          size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
                ),
                TextButton(
                  onPressed: () => widget.onChanged(null, null),
                  child: Text('Remove',
                      style: AppType.sans(
                          size: 12.5, weight: FontWeight.w700, color: AppColors.plum)),
                ),
              ],
            ),
          )
        else
          GhostButton(
            label: _locating ? 'Finding you…' : 'Use my current location',
            icon: Icons.my_location_rounded,
            tone: AppColors.emerald,
            onTap: _locating ? null : _useCurrent,
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppType.sans(size: 12, height: 1.4, color: AppColors.plum)),
          if (_blocked && !kIsWeb)
            TextButton(
              onPressed: () => ref.read(locationServiceProvider).openSettings(),
              child: Text('Open settings',
                  style: AppType.sans(
                      size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          'Tap this while you’re at the business, so customers see accurate distances.',
          style: AppType.sans(size: 11.5, height: 1.4, color: AppColors.inkA(0.5)),
        ),
      ],
    );
  }
}

// ─────────────── opening hours ───────────────

/// Always seven entries (Mon…Sun); days missing from [hours] count as closed.
/// With no hours at all, starts from [defaultWeekHours].
List<OpeningHours> normalizeWeek(List<OpeningHours> hours) {
  if (hours.isEmpty) return defaultWeekHours();
  final byDay = {for (final h in hours) h.dayOfWeek: h};
  return [
    for (var day = 0; day < 7; day++)
      byDay[day] ??
          OpeningHours(dayOfWeek: day, opens: '09:00', closes: '21:00', isClosed: true),
  ];
}

/// Weekly hours editor: an open/closed switch and opening/closing times per day.
class HoursEditor extends StatelessWidget {
  const HoursEditor({super.key, required this.hours, required this.onChanged});

  /// Seven entries, index = day of week (see [normalizeWeek]).
  final List<OpeningHours> hours;
  final ValueChanged<List<OpeningHours>> onChanged;

  void _set(int day, OpeningHours value) {
    final next = [...hours];
    next[day] = value;
    onChanged(next);
  }

  static TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pick(BuildContext context, int day, {required bool opening}) async {
    final entry = hours[day];
    final picked = await showTimePicker(
      context: context,
      initialTime: _parse(opening ? entry.opens : entry.closes),
      helpText: '${OpeningHours.dayNames[day]} · ${opening ? 'opens' : 'closes'}',
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final value = _format(picked);
    _set(day, opening ? entry.copyWith(opens: value) : entry.copyWith(closes: value));
  }

  void _copyMondayToAll() {
    final monday = hours.first;
    onChanged([
      for (var day = 0; day < 7; day++)
        OpeningHours(
          dayOfWeek: day,
          opens: monday.opens,
          closes: monday.closes,
          isClosed: monday.isClosed,
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var day = 0; day < 7; day++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(OpeningHours.dayNames[day],
                      style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
                ),
                KhojloToggle(
                  value: !hours[day].isClosed,
                  onChanged: (open) => _set(day, hours[day].copyWith(isClosed: !open)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: hours[day].isClosed
                      ? Text('Closed',
                          style: AppType.sans(size: 13, color: AppColors.inkA(0.45)))
                      : Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _TimeChip(
                                value: hours[day].opens,
                                onTap: () => _pick(context, day, opening: true)),
                            Text('–', style: AppType.mono(size: 12)),
                            _TimeChip(
                                value: hours[day].closes,
                                onTap: () => _pick(context, day, opening: false)),
                            if (hours[day].closes == hours[day].opens)
                              Text('24 hours',
                                  style: AppType.mono(size: 9.5, color: AppColors.emerald))
                            else if (hours[day].closes.compareTo(hours[day].opens) < 0)
                              Text('next day',
                                  style: AppType.mono(size: 9.5, color: AppColors.inkA(0.5))),
                          ],
                        ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'Copy Monday to every day',
          icon: Icons.copy_all_rounded,
          small: true,
          onTap: _copyMondayToAll,
        ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.75),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.inkA(0.1)),
        ),
        child: Text(value, style: AppType.mono(size: 12.5, weight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────── category ───────────────

/// Category chips under their group headings ("Food & Drink", "Shopping", ...).
/// Picking "Other" reveals a field for the owner's own description, which is
/// shown on cards and matched by search.
class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    required this.customController,
    this.onCustomChanged,
  });

  final int? selectedId;
  final ValueChanged<Category> onSelected;
  final TextEditingController customController;
  final VoidCallback? onCustomChanged;

  /// A message when "Other" is picked without a description, else null.
  static String? customError(Category? selected, String text) =>
      selected != null && selected.isOther && text.trim().length < 2
          ? 'Describe your business in a few words, e.g. “Calligraphy studio”.'
          : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(categoriesProvider).when(
          loading: () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 8; i++)
                SkeletonBox(width: 90 + (i % 3) * 24.0, height: 36, radius: 999),
            ],
          ),
          error: (_, __) => Row(
            children: [
              Expanded(
                child: Text('Couldn’t load categories',
                    style: AppType.sans(color: AppColors.inkA(0.6))),
              ),
              GhostButton(
                label: 'Retry',
                small: true,
                expand: false,
                onTap: () => ref.invalidate(categoriesProvider),
              ),
            ],
          ),
          data: (list) {
            final selected = list.where((c) => c.id == selectedId).firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (group, items) in groupCategories(list)) ...[
                  if (group.isNotEmpty) ...[
                    Text(group.toUpperCase(), style: AppType.label()),
                    const SizedBox(height: 8),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in items)
                        KhojloChip(
                          label: c.name,
                          emoji: c.emoji,
                          dense: true,
                          active: c.id == selectedId,
                          onTap: () => onSelected(c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                if (selected?.isOther ?? false)
                  AppField(
                    label: 'What kind of business is it?',
                    controller: customController,
                    hint: 'e.g. Calligraphy studio',
                    inputFormatters: [LengthLimitingTextInputFormatter(60)],
                    onChanged: (_) => onCustomChanged?.call(),
                  ),
              ],
            );
          },
        );
  }
}

// ─────────────── phone ───────────────

/// Optional contact number, checked the same way as the backend (7–15 digits).
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.onChanged,
    this.label = 'Phone number · optional',
  });

  final TextEditingController controller;
  final VoidCallback? onChanged;
  final String label;

  static final _allowed = RegExp(r'^\+?[\d\s\-()]+$');

  /// A message when the number doesn't look like one, else null (empty is fine).
  static String? validate(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final digits = t.replaceAll(RegExp(r'\D'), '').length;
    if (!_allowed.hasMatch(t) || digits < 7 || digits > 15) {
      return 'Enter a valid phone number, e.g. 0300 1234567';
    }
    return null;
  }

  /// The number to send: trimmed, or null to clear it.
  static String? value(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final error = validate(controller.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppField(
          label: label,
          controller: controller,
          hint: '0300 1234567',
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d\s+\-()]')),
            LengthLimitingTextInputFormatter(24),
          ],
          onChanged: (_) => onChanged?.call(),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error, style: AppType.sans(size: 12, color: AppColors.plum)),
        ],
      ],
    );
  }
}

// ─────────────── colour ───────────────

/// The listing's colour: used on cards whenever there's no photo.
class TonePicker extends StatelessWidget {
  const TonePicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  static const tones = ['gold', 'emerald', 'plum', 'coral', 'ink'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final t in tones)
          Semantics(
            button: true,
            selected: value == t,
            label: '$t colour',
            child: GestureDetector(
              onTap: () => onChanged(t),
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientFor(t),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == t ? AppColors.ink : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
