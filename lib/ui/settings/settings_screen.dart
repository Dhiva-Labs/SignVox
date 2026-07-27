import 'package:flutter/cupertino.dart' show CupertinoIcons, CupertinoSlider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_settings.dart';
import '../../core/providers.dart';
import '../../theme.dart';
import '../datalab/datalab_screen.dart';
import '../history/history_screen.dart';
import '../personalise/personalise_screen.dart';
import '../widgets/grouped.dart';
import '../widgets/nav.dart';
import '../widgets/segmented.dart';
import 'about_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final colors = context.colors;
    return ListenableBuilder(
      listenable: settings.data,
      builder: (context, _) {
        final s = settings.data.value;
        void set(AppSettingsData Function(AppSettingsData) fn) =>
            settings.update(fn);

        return SvLargeTitleScaffold(
          title: 'Settings',
          padForTabBar: true,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  GroupedSection(
                    header: 'Voice',
                    dividerIndent: 57,
                    children: [
                      _SliderRow(
                        leading: const IconBadge(
                          CupertinoIcons.speaker_2_fill,
                          color: BadgeColors.orange,
                        ),
                        title: 'Speaking Rate',
                        valueLabel: '${s.ttsRate.toStringAsFixed(1)}×',
                        value: s.ttsRate,
                        min: 0.6,
                        max: 1.6,
                        divisions: 10,
                        onChanged: (v) => set((c) => c.copyWith(ttsRate: v)),
                      ),
                      SvSwitchRow(
                        leading: const IconBadge(
                          CupertinoIcons.waveform,
                          color: BadgeColors.orange,
                        ),
                        title: 'Speak as You Sign',
                        subtitle: 'Off: only “Speak” reads the sentence',
                        value: s.speakPerWord,
                        onChanged: (v) =>
                            set((c) => c.copyWith(speakPerWord: v)),
                      ),
                    ],
                  ),
                  GroupedSection(
                    header: 'Recognition',
                    dividerIndent: 57,
                    children: [
                      _SliderRow(
                        leading: const IconBadge(
                          CupertinoIcons.timer,
                          color: BadgeColors.blue,
                        ),
                        title: 'Letter Hold Time',
                        valueLabel: '${s.letterHoldMs} ms',
                        // A duration, not a frame count: the same slider position
                        // means the same wait on a fast phone, a slow phone, and a
                        // phone that has got hot (PLAN_V2_RECOGNITION.md R3).
                        value: s.letterHoldMs.toDouble(),
                        min: 150,
                        max: 700,
                        divisions: 11,
                        onChanged: (v) => set(
                          (c) =>
                              c.copyWith(letterHoldMs: (v / 50).round() * 50),
                        ),
                      ),
                      SvSwitchRow(
                        leading: const IconBadge(
                          CupertinoIcons.person_crop_circle,
                          color: BadgeColors.purple,
                        ),
                        title: 'Personalised Recognition',
                        subtitle:
                            'Blend letters you’ve taught this phone into the model',
                        value: s.personalisationEnabled,
                        onChanged: (v) =>
                            set((c) => c.copyWith(personalisationEnabled: v)),
                      ),
                      SvSwitchRow(
                        leading: const IconBadge(
                          CupertinoIcons.hand_raised_fill,
                          color: BadgeColors.teal,
                        ),
                        title: 'Left-Handed Mode',
                        subtitle: 'Read your left hand as the dominant one',
                        value: s.leftHandedMode,
                        onChanged: (v) =>
                            set((c) => c.copyWith(leftHandedMode: v)),
                      ),
                      SvSwitchRow(
                        leading: const IconBadge(
                          CupertinoIcons.hand_draw,
                          color: BadgeColors.indigo,
                        ),
                        title: 'Hand Skeleton Overlay',
                        subtitle:
                            'Default for Translate — still toggleable there',
                        value: s.showOverlayByDefault,
                        onChanged: (v) =>
                            set((c) => c.copyWith(showOverlayByDefault: v)),
                      ),
                      SvSwitchRow(
                        leading: const IconBadge(
                          CupertinoIcons.thermometer,
                          color: BadgeColors.red,
                        ),
                        title: 'Adaptive Frame Rate',
                        subtitle:
                            'Lower camera FPS automatically when running hot',
                        value: s.adaptiveFpsEnabled,
                        onChanged: (v) =>
                            set((c) => c.copyWith(adaptiveFpsEnabled: v)),
                      ),
                      SvSwitchRow(
                        leading: const IconBadge(
                          CupertinoIcons.sun_max_fill,
                          color: BadgeColors.yellow,
                        ),
                        title: 'Keep Screen On',
                        subtitle:
                            'While translating — Conversation mode always does',
                        value: s.keepScreenOnWhileTranslating,
                        onChanged: (v) => set(
                          (c) => c.copyWith(keepScreenOnWhileTranslating: v),
                        ),
                      ),
                    ],
                  ),
                  GroupedSection(
                    header: 'Appearance',
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: SvSegmented<ThemeMode>(
                          value: s.themeMode,
                          onChanged: (m) =>
                              set((c) => c.copyWith(themeMode: m)),
                          segments: const [
                            (ThemeMode.system, 'System'),
                            (ThemeMode.light, 'Light'),
                            (ThemeMode.dark, 'Dark'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  GroupedSection(
                    dividerIndent: 57,
                    footer:
                        'SignVox runs entirely on this device — it has no internet '
                        'access at all, so nothing you sign or say ever leaves your phone.',
                    children: [
                      SvRow(
                        leading: const IconBadge(
                          CupertinoIcons.clock_fill,
                          color: BadgeColors.gray,
                        ),
                        title: 'History',
                        chevron: true,
                        onTap: () => _push(context, const HistoryScreen()),
                      ),
                      SvRow(
                        leading: const IconBadge(
                          CupertinoIcons.wand_stars,
                          color: BadgeColors.green,
                        ),
                        title: 'Improve Recognition',
                        subtitle: 'Teach this phone your own hand',
                        chevron: true,
                        onTap: () => _push(context, const PersonaliseScreen()),
                      ),
                      SvRow(
                        leading: const IconBadge(
                          CupertinoIcons.lab_flask,
                          color: BadgeColors.indigo,
                        ),
                        title: 'Data Lab',
                        subtitle:
                            'Record training samples for the letter model',
                        chevron: true,
                        onTap: () => _push(context, const DataLabScreen()),
                      ),
                      SvRow(
                        leading: const IconBadge(
                          CupertinoIcons.info,
                          color: BadgeColors.gray,
                        ),
                        title: 'About',
                        chevron: true,
                        onTap: () => _push(context, const AboutScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SignVox · Dhiva Labs',
                    style: TextStyle(fontSize: 12, color: colors.tertiaryLabel),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// iOS-style slider cell: badge + title + live value on the first line, a
/// CupertinoSlider stretched underneath.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.leading,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
  });

  final Widget leading;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: theme.bodyLarge)),
              Text(
                valueLabel,
                style: theme.bodyLarge?.copyWith(color: colors.secondaryLabel),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: CupertinoSlider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
