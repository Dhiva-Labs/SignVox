import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoIcons,
        CupertinoSearchTextField,
        CupertinoSwitch;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../data/sign_pack.dart';
import '../../data/sign_repository.dart';
import '../../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped.dart';
import '../widgets/nav.dart';
import '../widgets/sv_dialogs.dart';

class VocabularyScreen extends ConsumerStatefulWidget {
  const VocabularyScreen({super.key});

  @override
  ConsumerState<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends ConsumerState<VocabularyScreen> {
  List<SignSummary>? _signs;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final signs = await ref.read(signRepositoryProvider).allSigns();
    if (mounted) setState(() => _signs = signs);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleEnabled(SignSummary summary, bool enabled) async {
    await ref.read(signRepositoryProvider).setEnabled(summary.sign.id, enabled);
    _reload();
  }

  Future<void> _editSpokenText(SignSummary summary) async {
    final result = await showSvTextInput(
      context,
      title: 'Speak “${summary.sign.label}” As',
      initial: summary.sign.spokenText,
    );
    if (result == null || result.isEmpty) return;
    await ref
        .read(signRepositoryProvider)
        .updateSpokenText(summary.sign.id, result);
    _reload();
  }

  Future<void> _exportAll() async {
    final signs = _signs;
    if (signs == null || signs.isEmpty) return;
    final repo = ref.read(signRepositoryProvider);
    final json = await SignPack.export(repo, [
      for (final s in signs) s.sign.id,
    ]);

    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'signvox_pack.json'));
    await file.writeAsString(jsonEncode(json));

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: 'SignVox sign pack'),
    );
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final count = await SignPack.import(
        ref.read(signRepositoryProvider),
        json,
      );
      _toast('Imported $count sign${count == 1 ? '' : 's'}');
      _reload();
    } catch (e) {
      _toast('Import failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final signs = _signs;
    final colors = context.colors;
    final filtered = signs
        ?.where(
          (s) => s.sign.label.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();

    return SvLargeTitleScaffold(
      title: 'Vocabulary',
      padForTabBar: true,
      actions: [
        IconButton(
          tooltip: 'Import sign pack',
          icon: Icon(
            CupertinoIcons.square_arrow_down,
            size: 22,
            color: colors.accent,
          ),
          onPressed: _import,
        ),
        IconButton(
          tooltip: 'Export all signs',
          icon: Icon(
            CupertinoIcons.square_arrow_up,
            size: 22,
            color: (signs?.isEmpty ?? true)
                ? colors.tertiaryLabel
                : colors.accent,
          ),
          onPressed: (signs?.isEmpty ?? true) ? null : _exportAll,
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: CupertinoSearchTextField(
              placeholder: 'Search',
              style: TextStyle(fontSize: 17, color: colors.label),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
        ),
        if (signs == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 13)),
          )
        else if (signs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SvEmptyState(
              icon: CupertinoIcons.book,
              title: 'No Signs Yet',
              message:
                  'Teach a sign from the Teach tab, or import a sign pack '
                  'someone shared with you.',
            ),
          )
        else if (filtered!.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: SvEmptyState(
              icon: CupertinoIcons.search,
              title: 'No Results',
              message: 'No sign matches “$_search”.',
            ),
          )
        else
          SliverToBoxAdapter(
            child: GroupedSection(
              footer:
                  'Tap a sign to change what it speaks. '
                  'Disabled signs are ignored in Signs mode.',
              children: [
                for (final summary in filtered)
                  SvRow(
                    title: summary.sign.label,
                    subtitle: 'speaks “${summary.sign.spokenText}”',
                    onTap: () => _editSpokenText(summary),
                    trailing: CupertinoSwitch(
                      value: summary.sign.enabled,
                      activeTrackColor: colors.success,
                      onChanged: (v) => _toggleEnabled(summary, v),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
