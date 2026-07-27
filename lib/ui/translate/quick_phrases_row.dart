import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme.dart';
import '../widgets/sv_dialogs.dart';

/// User-editable canned phrases (PLAN.md §4 screen 4), one tap to speak
/// instantly from the TTS cache (§6.4). Rendered as glass capsules — this
/// row only ever appears over the dark conversation layout. Tap speaks,
/// long-press offers deletion.
class QuickPhrasesRow extends ConsumerStatefulWidget {
  const QuickPhrasesRow({super.key});

  @override
  ConsumerState<QuickPhrasesRow> createState() => _QuickPhrasesRowState();
}

class _QuickPhrasesRowState extends ConsumerState<QuickPhrasesRow> {
  List<Phrase>? _phrases;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final phrases = await ref.read(historyRepositoryProvider).allPhrases();
    if (mounted) setState(() => _phrases = phrases);
  }

  Future<void> _speak(Phrase phrase) async {
    ref.read(ttsServiceProvider).speak(phrase.phraseText);
    await ref.read(historyRepositoryProvider).addEntry(phrase.phraseText);
  }

  Future<void> _addPhrase() async {
    final text = await showSvTextInput(
      context,
      title: 'New Quick Phrase',
      placeholder: 'Thank you!',
      confirmLabel: 'Add',
    );
    if (text == null || text.isEmpty) return;
    await ref.read(historyRepositoryProvider).addPhrase(text);
    _reload();
  }

  Future<void> _deletePhrase(Phrase phrase) async {
    final confirmed = await showSvConfirm(
      context,
      title: 'Delete Phrase?',
      message: '“${phrase.phraseText}”',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(historyRepositoryProvider).deletePhrase(phrase.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final phrases = _phrases;
    final accent = context.colors.accent;
    return SizedBox(
      height: 40,
      child: phrases == null
          ? const SizedBox.shrink()
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final phrase in phrases)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _PhraseCapsule(
                      label: phrase.phraseText,
                      onTap: () => _speak(phrase),
                      onLongPress: () => _deletePhrase(phrase),
                    ),
                  ),
                _PhraseCapsule(
                  label: 'Add',
                  icon: CupertinoIcons.plus,
                  tint: accent.withValues(alpha: 0.38),
                  onTap: _addPhrase,
                ),
              ],
            ),
    );
  }
}

class _PhraseCapsule extends StatelessWidget {
  const _PhraseCapsule({
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tint ?? Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
