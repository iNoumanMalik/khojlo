import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Labelled text field styled like the bundle's `Field` primitive
/// (mono uppercase label + translucent rounded input).
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.inputFormatters,
    this.prefixText,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;

  /// Fixed text before the input, e.g. "Rs ".
  final String? prefixText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppType.label(color: AppColors.inkA(0.47))),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: maxLines,
          inputFormatters: inputFormatters,
          style: AppType.sans(size: 14.5, weight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            // Always visible (unlike `prefixText`, which hides until the field is focused).
            prefixIcon: prefixText == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 16, right: 6),
                    child: Text(prefixText!.trim(),
                        style: AppType.mono(size: 13, color: AppColors.inkA(0.5))),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            hintStyle: AppType.sans(
                size: 14.5, weight: FontWeight.w500, color: AppColors.inkA(0.33)),
            filled: true,
            fillColor: AppColors.whiteA(0.7),
            contentPadding: EdgeInsets.fromLTRB(prefixText == null ? 16 : 0, 14, 16, 14),
            border: _border(AppColors.inkA(0.08)),
            enabledBorder: _border(AppColors.inkA(0.08)),
            focusedBorder: _border(AppColors.emerald.withValues(alpha: 0.6)),
            errorBorder: _border(AppColors.plum.withValues(alpha: 0.6)),
            focusedErrorBorder: _border(AppColors.plum.withValues(alpha: 0.7)),
            errorStyle: AppType.sans(size: 11, color: AppColors.plum),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: 1.5),
      );
}

/// iOS-style segmented control (Sign in / Sign up).
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == activeIndex ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == activeIndex
                        ? [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      options[i],
                      style: AppType.sans(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: i == activeIndex
                            ? AppColors.ink
                            : AppColors.inkA(0.4),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
