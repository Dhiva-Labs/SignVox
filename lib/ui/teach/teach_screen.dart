import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/sign_repository.dart';
import '../../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped.dart';
import '../widgets/nav.dart';
import 'teach_wizard_screen.dart';

class TeachScreen extends ConsumerStatefulWidget {
  const TeachScreen({super.key});

  @override
  ConsumerState<TeachScreen> createState() => _TeachScreenState();
}

class _TeachScreenState extends ConsumerState<TeachScreen> {
  List<SignSummary>? _signs;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final signs = await ref.read(signRepositoryProvider).allSigns();
    if (mounted) setState(() => _signs = signs);
  }

  Future<void> _launchWizard() async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const TeachWizardScreen()));
    if (saved == true) _reload();
  }

  Future<void> _delete(SignSummary summary) async {
    await ref.read(signRepositoryProvider).deleteSign(summary.sign.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final signs = _signs;
    final colors = context.colors;
    return SvLargeTitleScaffold(
      title: 'Teach',
      padForTabBar: true,
      actions: [
        IconButton(
          onPressed: _launchWizard,
          tooltip: 'Teach a sign',
          icon: Icon(CupertinoIcons.plus, size: 24, color: colors.accent),
        ),
      ],
      slivers: [
        if (signs == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CupertinoActivityIndicator(radius: 13)),
          )
        else if (signs.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: SvEmptyState(
              icon: CupertinoIcons.square_stack_3d_up,
              title: 'No Signs Yet',
              message:
                  'Teach SignVox a whole word-sign — five quick repetitions '
                  'and it speaks the moment you sign it.',
              action: OutlinedButton(
                onPressed: _launchWizard,
                child: const Text('Teach a Sign'),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: GroupedSection(
              footer:
                  'Swipe a sign to delete it. Signs can be shared as packs '
                  'from the Vocabulary tab.',
              children: [
                for (final summary in signs)
                  Dismissible(
                    key: ValueKey(summary.sign.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: colors.destructive,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        CupertinoIcons.trash_fill,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    onDismissed: (_) => _delete(summary),
                    child: SvRow(
                      title: summary.sign.label,
                      subtitle:
                          '${summary.exemplarCount} sample${summary.exemplarCount == 1 ? '' : 's'} · '
                          'speaks “${summary.sign.spokenText}”',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
