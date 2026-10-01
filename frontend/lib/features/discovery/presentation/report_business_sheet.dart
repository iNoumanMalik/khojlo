import 'package:flutter/material.dart';

import '../../../core/models/moderation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Module 8: why a business listing is being reported (FR-19, extended to
/// businesses). For Khojlo's moderators; the owner isn't told who reported it.
Future<(BusinessReportReason, String)?> showReportBusinessSheet(
        BuildContext context, String businessName) =>
    showModalBottomSheet<(BusinessReportReason, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _ReportSheet(businessName: businessName),
      ),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.businessName});
  final String businessName;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  BusinessReportReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.inkA(0.15), borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text('Report ${widget.businessName}', style: AppType.serif(size: 22)),
          const SizedBox(height: 4),
          Text('Khojlo’s team will check it. The owner won’t know who reported it.',
              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
          const SizedBox(height: 10),
          RadioGroup<BusinessReportReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final reason in BusinessReportReason.values)
                  RadioListTile<BusinessReportReason>(
                    value: reason,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.emerald,
                    title: Text(reason.label, style: AppType.sans(size: 14)),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 500,
            maxLines: 3,
            minLines: 1,
            style: AppType.sans(size: 14),
            decoration: InputDecoration(
              hintText: 'What did you notice? (optional)',
              hintStyle: AppType.sans(size: 13.5, color: AppColors.inkA(0.4)),
              filled: true,
              fillColor: AppColors.whiteA(0.8),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Send report',
            tone: ButtonTone.ink,
            onTap: _reason == null
                ? null
                : () => Navigator.of(context).pop((_reason!, _note.text.trim())),
          ),
        ],
      ),
    );
  }
}
