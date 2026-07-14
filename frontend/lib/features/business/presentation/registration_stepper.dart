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

class RegistrationStepper extends ConsumerStatefulWidget {
  const RegistrationStepper({super.key});

  @override
  ConsumerState<RegistrationStepper> createState() =>
      _RegistrationStepperState();
}

class _RegistrationStepperState extends ConsumerState<RegistrationStepper> {
  final _draft = BusinessDraft();
  int _step = 0;
  bool _publishing = false;
  bool _done = false;
  String? _error;

  final _name = TextEditingController();
  final _tagline = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _serviceName = TextEditingController();

  static const _steps = ['Name', 'Category', 'Location', 'About', 'Services', 'Review'];
  static const _tones = ['gold', 'emerald', 'plum', 'coral', 'ink'];

  @override
  void dispose() {
    for (final c in [_name, _tagline, _description, _address, _serviceName]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canAdvance => switch (_step) {
        0 => _name.text.trim().isNotEmpty,
        1 => _draft.categoryId != null,
        _ => true,
      };

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _publish();
    }
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _error = null;
    });
    _draft
      ..name = _name.text.trim()
      ..tagline = _tagline.text.trim()
      ..description = _description.text.trim()
      ..address = _address.text.trim();
    try {
      await ref.read(businessRepositoryProvider).create(_draft);
      ref.invalidate(myBusinessesProvider);
      ref.invalidate(feedProvider);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = describeApiError(e));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _CompletionScreen(name: _draft.name);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _progress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _stepBody(),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(_error!,
                    style: AppType.sans(size: 12.5, color: AppColors.plum)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: PrimaryButton(
                label: _step == _steps.length - 1 ? 'Publish business' : 'Continue',
                tone: ButtonTone.emerald,
                loading: _publishing,
                onTap: _canAdvance ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.chevron_left_rounded,
            size: 38,
            onTap: () => _step == 0
                ? context.pop()
                : setState(() => _step--),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STEP ${_step + 1} OF ${_steps.length} · ${_steps[_step].toUpperCase()}',
                    style: AppType.label()),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps.length,
                    minHeight: 6,
                    backgroundColor: AppColors.ink.withValues(alpha: 0.08),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.emerald),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody() {
    return switch (_step) {
      0 => _nameStep(),
      1 => _categoryStep(),
      2 => _locationStep(),
      3 => _aboutStep(),
      4 => _servicesStep(),
      _ => _reviewStep(),
    };
  }

  Widget _heading(String eyebrow, String title, String sub) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(eyebrow, style: AppType.label()),
          const SizedBox(height: 12),
          Text(title, style: AppType.serif(size: 30, height: 1.1)),
          const SizedBox(height: 8),
          Text(sub,
              style: AppType.sans(
                  size: 13.5, height: 1.5, color: AppColors.inkA(0.53))),
          const SizedBox(height: 24),
        ],
      );

  Widget _nameStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('LET’S START', 'What’s your\nbusiness called?',
              'This is how people will find you on Khojlo.'),
          AppField(
              label: 'Business name',
              controller: _name,
              hint: 'e.g. Brew & Bloom',
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 24),
          Text('PICK A COLOR', style: AppType.label()),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final t in _tones) ...[
                GestureDetector(
                  onTap: () => setState(() => _draft.tone = t),
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
                        color: _draft.tone == t
                            ? AppColors.ink
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      );

  Widget _categoryStep() {
    final cats = ref.watch(categoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('CATEGORY', 'What kind of\nbusiness is it?',
            'We’ll show you in the right discovery sections.'),
        cats.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.emerald)),
          error: (_, __) => Text('Couldn’t load categories',
              style: AppType.sans(color: AppColors.inkA(0.6))),
          data: (list) => Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in list)
                KhojloChip(
                  label: c.name,
                  active: _draft.categoryId == c.id,
                  onTap: () => setState(() {
                    _draft.categoryId = c.id;
                    _draft.tone = c.tone;
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _locationStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('LOCATION', 'Where can\npeople find you?',
              'An address helps us place you on the map and nearby feeds.'),
          AppField(
              label: 'Address',
              controller: _address,
              hint: 'Street, area, city'),
        ],
      );

  Widget _aboutStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('THE PITCH', 'Tell people\nwhy they’ll love it.',
              'A short tagline and a description go a long way.'),
          AppField(
              label: 'Tagline',
              controller: _tagline,
              hint: 'Specialty coffee & a wall of plants'),
          const SizedBox(height: 16),
          AppField(
              label: 'Description',
              controller: _description,
              hint: 'What makes you special?',
              maxLines: 4),
          const SizedBox(height: 16),
          Text('PRICE LEVEL', style: AppType.label()),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final p in const ['\$', '\$\$', '\$\$\$']) ...[
                GestureDetector(
                  onTap: () => setState(() => _draft.priceLevel = p),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: _draft.priceLevel == p
                          ? AppColors.emerald
                          : AppColors.whiteA(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inkA(0.08)),
                    ),
                    child: Text(p,
                        style: AppType.mono(
                            size: 14,
                            color: _draft.priceLevel == p
                                ? Colors.white
                                : AppColors.ink)),
                  ),
                ),
              ],
            ],
          ),
        ],
      );

  Widget _servicesStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('SERVICES', 'What do you\noffer?',
              'Optional — add a few signature services or items.'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppField(
                    label: 'Service', controller: _serviceName, hint: 'e.g. Pour over'),
              ),
              const SizedBox(width: 10),
              GlassIconButton(
                icon: Icons.add_rounded,
                onTap: () {
                  final n = _serviceName.text.trim();
                  if (n.isNotEmpty) {
                    setState(() {
                      _draft.services.add((name: n, price: _draft.priceLevel));
                      _serviceName.clear();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final s in _draft.services)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: AppColors.emerald),
                  const SizedBox(width: 8),
                  Text(s.name, style: AppType.sans(size: 14)),
                ],
              ),
            ),
        ],
      );

  Widget _reviewStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('ALMOST THERE', 'Review &\npublish.',
              'Here’s how your listing looks. You can edit anytime.'),
          _reviewCard(),
        ],
      );

  Widget _reviewCard() {
    final preview = BusinessCard(
      id: 0,
      name: _name.text.trim().isEmpty ? 'Your business' : _name.text.trim(),
      tagline: _tagline.text.trim(),
      tone: _draft.tone,
      address: _address.text.trim(),
      priceLevel: _draft.priceLevel,
      rating: 0,
      reviewCount: 0,
      saveCount: 0,
      isVerified: false,
    );
    return GlassSurface(
      radius: 24,
      opacity: 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ImageTile(height: 130, tone: _draft.tone, radius: 16),
          const SizedBox(height: 12),
          Text(preview.name, style: AppType.serif(size: 20)),
          if (preview.tagline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(preview.tagline,
                style: AppType.sans(size: 13, color: AppColors.inkA(0.6))),
          ],
          const SizedBox(height: 10),
          Text(
            '${preview.priceLevel}'
            '${_draft.services.isNotEmpty ? ' · ${_draft.services.length} services' : ''}'
            '${preview.address.isNotEmpty ? ' · ${preview.address}' : ''}',
            style: AppType.mono(size: 11, color: AppColors.inkA(0.53)),
          ),
        ],
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          const Positioned.fill(child: MeshBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: AppColors.emerald, shape: BoxShape.circle),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text('You’re live!', style: AppType.serif(size: 36)),
                  const SizedBox(height: 10),
                  Text(
                    '$name is now on Khojlo and can start appearing in discovery feeds. Manage everything from your dashboard.',
                    style: AppType.sans(
                        size: 14, height: 1.55, color: AppColors.inkA(0.6)),
                  ),
                  const SizedBox(height: 28),
                  PrimaryButton(
                    label: 'Go to dashboard',
                    tone: ButtonTone.emerald,
                    onTap: () => context.go('/business'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
