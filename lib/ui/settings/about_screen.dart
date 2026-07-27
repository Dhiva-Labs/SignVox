import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme.dart';
import '../widgets/grouped.dart';
import '../widgets/nav.dart';

/// PLAN.md §4 screen 7 About: version, and licenses for everything bundled —
/// the MediaPipe HandLandmarker model, the Piper/sherpa-onnx voice (whose
/// dataset license is the whole reason `en_US-ljspeech-medium` was chosen
/// over the plan's original suggestion — see PLAN.md's P4 gotchas and
/// `assets/tts/LICENSE`), the Inter typeface (OFL, registered in main.dart),
/// and every pub package via Flutter's own license registry.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SvLargeTitleScaffold(
      title: 'About',
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              const SizedBox(height: 18),
              const _AppHeader(),
              GroupedSection(
                header: 'Bundled models & voice',
                children: const [
                  SvRow(
                    title: 'MediaPipe HandLandmarker',
                    subtitle: 'Apache 2.0 — Google — hand-tracking model',
                  ),
                  SvRow(
                    title: 'Piper voice — en_US-ljspeech-medium',
                    subtitle:
                        'Public-domain dataset (LJ Speech) — offline voice',
                  ),
                  SvRow(
                    title: 'Inter typeface',
                    subtitle: 'SIL Open Font License 1.1 — The Inter Project',
                  ),
                  SvRow(
                    title: 'Word-suggestion list',
                    subtitle: 'MIT — FrequencyWords (OpenSubtitles corpus)',
                  ),
                ],
              ),
              GroupedSection(
                footer:
                    'SignVox runs entirely on this device. It never requests '
                    'internet access — signing, recognition, and speech synthesis all '
                    'happen locally, and nothing you sign or say is ever uploaded.',
                children: [
                  SvRow(
                    title: 'Open-Source Licenses',
                    subtitle:
                        'Flutter, Riverpod, drift, sherpa-onnx, and the rest',
                    chevron: true,
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'SignVox',
                      applicationLegalese: '© Dhiva Labs',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                CupertinoIcons.hand_raised_fill,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            Text('SignVox', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 3),
            Text(
              info == null
                  ? 'Loading…'
                  : 'Version ${info.version} (${info.buildNumber})',
              style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
            ),
          ],
        );
      },
    );
  }
}
