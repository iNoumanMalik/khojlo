import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Suggested replies, then the message field with photo and send buttons.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    this.onPhoto,
    this.onTyping,
    this.suggestions = const [],
  });

  final ValueChanged<String> onSend;
  final VoidCallback? onPhoto;
  final VoidCallback? onTyping;

  /// Quick messages shown as chips; tapping one sends it.
  final List<String> suggestions;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _text.clear();
    setState(() {});
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _text.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.suggestions.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final s in widget.suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: KhojloChip(label: s, onTap: () => widget.onSend(s)),
                  ),
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              if (widget.onPhoto != null)
                Semantics(
                  button: true,
                  label: 'Send a photo',
                  child: GlassIconButton(
                      icon: Icons.add_photo_alternate_outlined, size: 46, onTap: widget.onPhoto),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassSurface(
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    onChanged: (_) {
                      setState(() {});
                      widget.onTyping?.call();
                    },
                    style: AppType.sans(size: 14),
                    decoration: InputDecoration(
                      hintText: 'Message…',
                      hintStyle: AppType.sans(size: 14, color: AppColors.inkA(0.45)),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Send',
                child: GestureDetector(
                  onTap: canSend ? _send : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: canSend ? AppColors.ink : AppColors.inkA(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
