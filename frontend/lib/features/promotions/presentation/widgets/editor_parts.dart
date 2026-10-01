import 'package:flutter/material.dart';

import '../../../../core/models/business.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Section heading inside the offer / campaign editors.
class EditorLabel extends StatelessWidget {
  const EditorLabel(this.text, {super.key, this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.toUpperCase(), style: AppType.label()),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: AppType.sans(size: 11.5, color: AppColors.inkA(0.5))),
          ],
        ],
      ),
    );
  }
}

/// A plain multi-line text box in the editors' style.
class EditorTextField extends StatelessWidget {
  const EditorTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.fieldKey,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: keyboardType,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      style: AppType.sans(size: 14, height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppType.sans(size: 13.5, color: AppColors.inkA(0.4)),
        filled: true,
        fillColor: AppColors.whiteA(0.8),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.inkA(0.08))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.emerald, width: 1.4)),
      ),
    );
  }
}

/// A tappable date ("Starts 3 Oct 2026") that opens the date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.first,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final DateTime? first;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: ${value == null ? 'not set' : shortDate(value!)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () async {
          final now = DateTime.now();
          final start = first ?? DateTime(now.year - 1);
          final initial = value ?? now;
          final picked = await showDatePicker(
            context: context,
            firstDate: start,
            lastDate: DateTime(now.year + 3),
            initialDate: initial.isBefore(start) ? start : initial,
          );
          if (picked != null) onPicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.whiteA(0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inkA(0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18, color: AppColors.emerald),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppType.mono(size: 9.5, color: AppColors.inkA(0.5))),
                    Text(value == null ? 'Pick a date' : '${shortDate(value!)} ${value!.year}',
                        style: AppType.sans(size: 13.5, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled switch with an optional explanation underneath.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;

  /// null disables the switch (e.g. an unverified business can't publish).
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.emerald,
      title: Text(title, style: AppType.sans(size: 14, weight: FontWeight.w600)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: AppType.sans(size: 12, height: 1.35, color: AppColors.inkA(0.55))),
    );
  }
}

/// Error line under a form.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.plum),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style: AppType.sans(size: 12.5, height: 1.35, color: AppColors.plum)),
          ),
        ],
      ),
    );
  }
}
