import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/media/media_repository.dart';
import '../../../core/media/photo_source.dart';
import '../../../core/models/business.dart';
import '../../../core/models/photo.dart';
import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../../business/business_providers.dart';
import '../../business/presentation/widgets/business_form_fields.dart';

/// Profile → Edit profile: photo, name, phone, avatar colour and interests.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider.select((s) => s.user));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : _EditProfileForm(user: user),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  late Photo? _avatar = widget.user.avatar;
  late String _tone = widget.user.avatarTone;
  late final Set<String> _interests = {...widget.user.interests};

  /// The photo being uploaded, shown in the avatar meanwhile.
  Uint8List? _uploadingBytes;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  String get _initials {
    final parts = _name.text.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return widget.user.initials;
    return parts.length == 1
        ? parts.first[0].toUpperCase()
        : (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _changePhoto() async {
    final picked = await ref.read(photoSourceProvider).pickOne();
    if (picked == null || !mounted) return;
    setState(() {
      _uploadingBytes = picked.bytes;
      _error = null;
    });
    try {
      final photo = await ref
          .read(mediaRepositoryProvider)
          .upload(picked.bytes, filename: picked.name);
      if (mounted) setState(() => _avatar = photo);
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _uploadingBytes = null);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final problem = name.isEmpty ? 'Your name can’t be empty.' : PhoneField.validate(_phone.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).saveProfile(
            fullName: name,
            avatarTone: _tone,
            phone: PhoneField.value(_phone),
            avatarKey: _avatar?.key,
            interests: _interests.toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.ink,
          content: Text('Profile saved', style: AppType.sans(size: 13, color: Colors.white)),
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
    final uploading = _uploadingBytes != null;
    return Column(
      children: [
        TopBar(title: 'Edit profile', onBack: () => context.pop()),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            children: [
              Center(child: _avatarPreview()),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  GhostButton(
                    label: uploading
                        ? 'Uploading…'
                        : _avatar == null
                            ? 'Add photo'
                            : 'Change photo',
                    small: true,
                    expand: false,
                    icon: Icons.photo_camera_outlined,
                    onTap: uploading ? null : _changePhoto,
                  ),
                  if (_avatar != null && !uploading)
                    GhostButton(
                      label: 'Remove',
                      small: true,
                      expand: false,
                      tone: AppColors.plum,
                      onTap: () => setState(() => _avatar = null),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              AppField(
                label: 'Full name',
                controller: _name,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text('EMAIL', style: AppType.label(color: AppColors.inkA(0.47))),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: Text(widget.user.email,
                        style: AppType.sans(size: 14.5, color: AppColors.inkA(0.6))),
                  ),
                  if (widget.user.isVerified)
                    const KhojloBadge(label: 'Verified', tone: BadgeTone.emerald),
                ],
              ),
              const SizedBox(height: 16),
              PhoneField(controller: _phone, onChanged: () => setState(() {})),
              const SizedBox(height: 24),
              Text('AVATAR COLOR', style: AppType.label()),
              const SizedBox(height: 4),
              Text('Behind your initials when you don’t have a photo.',
                  style: AppType.sans(size: 12.5, color: AppColors.inkA(0.5))),
              const SizedBox(height: 12),
              TonePicker(value: _tone, onChanged: (t) => setState(() => _tone = t)),
              const SizedBox(height: 26),
              Text('INTERESTS', style: AppType.label()),
              const SizedBox(height: 4),
              Text('We use these to tune your feed.',
                  style: AppType.sans(size: 12.5, color: AppColors.inkA(0.5))),
              const SizedBox(height: 14),
              _interestPicker(),
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
              label: 'Save profile',
              tone: ButtonTone.emerald,
              loading: _saving,
              onTap: uploading ? null : _save,
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarPreview() {
    const size = 96.0;
    final bytes = _uploadingBytes;
    if (bytes != null) {
      return SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipOval(child: Image.memory(bytes, fit: BoxFit.cover)),
            const Padding(
              padding: EdgeInsets.all(30),
              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
            ),
          ],
        ),
      );
    }
    return KhojloAvatar(initials: _initials, tone: _tone, size: size, photo: _avatar);
  }

  Widget _interestPicker() {
    return ref.watch(categoriesProvider).when(
          loading: () => const SkeletonBox(height: 120, radius: 16),
          error: (_, __) => Text('Couldn’t load interests',
              style: AppType.sans(color: AppColors.inkA(0.6))),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (group, items) in groupCategories(list.where((c) => !c.isOther))) ...[
                if (group.isNotEmpty) ...[
                  Text(group, style: AppType.sans(size: 12.5, weight: FontWeight.w600)),
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
                        active: _interests.contains(c.slug),
                        onTap: () => setState(() {
                          if (!_interests.remove(c.slug)) _interests.add(c.slug);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        );
  }
}
