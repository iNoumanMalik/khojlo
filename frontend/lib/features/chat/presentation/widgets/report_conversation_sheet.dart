import 'package:flutter/material.dart';

import '../../../../core/models/chat.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Asks why the conversation is being reported (for Module 8's moderators).
Future<(ConversationReportReason, String)?> showReportConversationSheet(BuildContext context) =>
    showModalBottomSheet<(ConversationReportReason, String)>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const _ReportSheet(),
      ),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ConversationReportReason? _reason;
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
          Text('Report this conversation', style: AppType.serif(size: 22)),
          const SizedBox(height: 4),
          // Decision 8 (SEC-5 exception): reporting shares the conversation with moderators.
          Text(
              'Reporting shares this conversation with Khojlo’s moderators so they can check '
              'it. The other person won’t know who reported it.',
              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
          const SizedBox(height: 10),
          RadioGroup<ConversationReportReason>(
            groupValue: _reason,
            onChanged: (v) => setState(() => _reason = v),
            child: Column(
              children: [
                for (final reason in ConversationReportReason.values)
                  RadioListTile<ConversationReportReason>(
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
              hintText: 'Anything else we should know? (optional)',
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
