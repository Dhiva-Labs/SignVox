import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';

/// Shows [OnboardingScreen] once, before [child], on first launch only
/// (PLAN.md §4 screen 8). A plain widget (not Riverpod) — this is a one-shot
/// gate checked once at app start, not shared reactive state.
class OnboardingGate extends StatefulWidget {
  const OnboardingGate({super.key, required this.child});

  final Widget child;

  static const _prefsKey = 'onboarding_complete_v1';

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<OnboardingGate> {
  bool? _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(OnboardingGate._prefsKey) ?? false;
    if (mounted) setState(() => _needsOnboarding = !done);
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingGate._prefsKey, true);
    if (mounted) setState(() => _needsOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final needs = _needsOnboarding;
    if (needs == null) return const SizedBox.shrink();
    if (needs) return OnboardingScreen(onDone: _complete);
    return widget.child;
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 3;

  Future<void> _next() async {
    if (_page == 1) {
      // Ask for camera permission here, with context already given — this
      // is a courtesy, not a gate: Translate re-requests and handles a
      // denial gracefully on its own, so a failure here (or no platform
      // channel at all, as in a widget test) must never block onboarding.
      try {
        await Permission.camera.request();
      } catch (e) {
        debugPrint(
          'Onboarding: camera permission pre-request failed, continuing anyway: $e',
        );
      }
    }
    if (_page == _pageCount - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _OnboardingPage(
                    icon: CupertinoIcons.hand_raised_fill,
                    title: 'Sign, and SignVox speaks for you',
                    body:
                        'Spell words letter by letter, or teach SignVox your own signs. '
                        'Everything runs on this phone — nothing you sign ever leaves it.',
                  ),
                  _OnboardingPage(
                    icon: CupertinoIcons.videocam_fill,
                    title: 'The camera reads your hands',
                    body:
                        'SignVox needs camera access to track your hand shapes and movement. '
                        "It's processed on-device only, in real time, and never recorded or uploaded.",
                  ),
                  _OnboardingPage(
                    icon: CupertinoIcons.device_phone_portrait,
                    title: 'Hold the phone at chest height',
                    body:
                        'Keep your signing hand clearly in frame, in good light. '
                        'Want SignVox to learn your own signs? Head to the Teach tab any time.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _page ? colors.accent : colors.fill,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _page == _pageCount - 1 ? 'Get started' : 'Continue',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 50, color: colors.accent),
          ),
          const SizedBox(height: 36),
          Text(title, style: theme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text(
            body,
            style: theme.bodyLarge?.copyWith(
              color: colors.secondaryLabel,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
