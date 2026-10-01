import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';

/// Confirms and performs permanent account deletion (SRS FR-32). Resolves true once
/// the account is gone (and the user signed out).
Future<bool> showDeleteAccountSheet(BuildContext context) async {
  final deleted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: const _DeleteAccountSheet(),
    ),
  );
  return deleted ?? false;
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete(bool needsPassword) async {
    if (needsPassword && _password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: needsPassword ? _password.text : null);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = describeApiError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final needsPassword = user?.hasPassword ?? true;
    final owner = user?.isOwner ?? false;
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
          Text('Delete your account?', style: AppType.serif(size: 22)),
          const SizedBox(height: 6),
          Text(
            'This permanently removes your profile, photos, reviews, saved places, '
            'conversations and search history${owner ? ', and every business you listed' : ''}. '
            'It can’t be undone.',
            style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.6)),
          ),
          const SizedBox(height: 18),
          if (needsPassword) ...[
            AppField(
              label: 'Password',
              controller: _password,
              hint: '••••••••',
              obscure: true,
            ),
            const SizedBox(height: 12),
          ],
          if (_error != null) ...[
            Text(_error!, style: AppType.sans(size: 12.5, color: AppColors.plum)),
            const SizedBox(height: 12),
          ],
          GhostButton(
            label: _deleting ? 'Deleting…' : 'Delete my account',
            tone: AppColors.plum,
            icon: Icons.delete_forever_outlined,
            onTap: _deleting ? null : () => _delete(needsPassword),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Keep my account',
            onTap: _deleting ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
