import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped.dart';
import '../widgets/nav.dart';
import '../widgets/sv_dialogs.dart';

/// Spoken-sentence history (PLAN.md §4 screen 6): tap an entry to re-speak
/// it, bookmark it to save it as a quick phrase for Conversation mode.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<HistoryEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final entries = await ref.read(historyRepositoryProvider).allEntries();
    if (mounted) setState(() => _entries = entries);
  }

  Future<void> _clearAll() async {
    final confirmed = await showSvConfirm(
      context,
      title: 'Clear History?',
      message: 'This removes every entry. Quick phrases are not affected.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(historyRepositoryProvider).clearAll();
    _reload();
  }

  Future<void> _saveAsPhrase(HistoryEntry entry) async {
    await ref.read(historyRepositoryProvider).addPhrase(entry.spokenText);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved as a quick phrase')));
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final sameDay =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (sameDay) return time;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} $time';
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final colors = context.colors;
    return SvLargeTitleScaffold(
      title: 'History',
      actions: [
        if (entries != null && entries.isNotEmpty)
          TextButton(
            onPressed: _clearAll,
            child: Text(
              'Clear',
              style: TextStyle(color: colors.destructive, fontSize: 17),
            ),
          ),
      ],
      slivers: [
        if (entries == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 13)),
          )
        else if (entries.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SvEmptyState(
              icon: CupertinoIcons.clock,
              title: 'Nothing Spoken Yet',
              message:
                  'Sentences you speak in Translate or Conversation mode '
                  'show up here — tap one to say it again.',
            ),
          )
        else
          SliverToBoxAdapter(
            child: GroupedSection(
              footer:
                  'Tap to speak again · bookmark to save as a quick phrase.',
              children: [
                for (final entry in entries)
                  SvRow(
                    title: entry.spokenText,
                    subtitle: _formatTimestamp(entry.spokenAt),
                    onTap: () =>
                        ref.read(ttsServiceProvider).speak(entry.spokenText),
                    trailing: IconButton(
                      tooltip: 'Save as quick phrase',
                      icon: Icon(
                        CupertinoIcons.bookmark,
                        size: 20,
                        color: colors.accent,
                      ),
                      onPressed: () => _saveAsPhrase(entry),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
