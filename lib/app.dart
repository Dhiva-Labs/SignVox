import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'theme.dart';
import 'ui/onboarding/onboarding_screen.dart';
import 'ui/settings/settings_screen.dart';
import 'ui/teach/teach_screen.dart';
import 'ui/translate/translate_screen.dart';
import 'ui/vocabulary/vocabulary_screen.dart';
import 'ui/widgets/nav.dart';

class SignVoxApp extends ConsumerWidget {
  const SignVoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).data;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'SignVox',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: settings.value.themeMode,
          home: const OnboardingGate(child: _NavShell()),
        );
      },
    );
  }
}

class _NavShell extends StatefulWidget {
  const _NavShell();

  @override
  State<_NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<_NavShell> {
  int _index = 0;

  static const _tabs = [
    TranslateScreen(),
    TeachScreen(),
    VocabularyScreen(),
    SettingsScreen(),
  ];

  void _select(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    // extendBody floats content behind the translucent tab bar — that live
    // camera (or list content) bleeding through the frost is the entire look.
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: _SvTabBar(
        index: _index,
        onSelected: _select,
        items: const [
          _SvTabItem(
            'Translate',
            CupertinoIcons.hand_raised,
            CupertinoIcons.hand_raised_fill,
          ),
          _SvTabItem(
            'Teach',
            CupertinoIcons.square_stack_3d_up,
            CupertinoIcons.square_stack_3d_up_fill,
          ),
          _SvTabItem(
            'Vocabulary',
            CupertinoIcons.book,
            CupertinoIcons.book_fill,
          ),
          _SvTabItem(
            'Settings',
            CupertinoIcons.gear,
            CupertinoIcons.gear_solid,
          ),
        ],
      ),
    );
  }
}

class _SvTabItem {
  const _SvTabItem(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// iOS tab bar: 50pt of frosted glass with a top hairline, accent-tinted
/// active tab, no ripples, no pill indicators.
class _SvTabBar extends StatelessWidget {
  const _SvTabBar({
    required this.index,
    required this.onSelected,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<_SvTabItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inactive = colors.secondaryLabel;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          decoration: BoxDecoration(
            color: colors.bg.withValues(alpha: 0.78),
            border: Border(
              top: BorderSide(color: colors.separator, width: 0.33),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: kSvTabBarHeight,
              child: Row(
                children: [
                  for (final (i, item) in items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == index,
                        button: true,
                        label: item.label,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                i == index ? item.activeIcon : item.icon,
                                size: 25,
                                color: i == index ? colors.accent : inactive,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.1,
                                  color: i == index ? colors.accent : inactive,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
