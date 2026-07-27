import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sign_vox/app.dart';

void main() {
  testWidgets('nav shell shows all four tabs and switches between them', (tester) async {
    // Skip past onboarding (OnboardingGate reads this from prefs) — this
    // test is about the nav shell, not first-run onboarding.
    SharedPreferences.setMockInitialValues({'onboarding_complete_v1': true});

    // Translate's camera bootstrap keeps a CircularProgressIndicator spinning
    // (its platform-channel call never resolves in the test sandbox), and
    // IndexedStack keeps that tab mounted even when another tab is selected —
    // so pumpAndSettle would wait on that animation forever. Bounded pumps
    // advance the nav-shell's own (non-animating) setState instead. Teach
    // and Vocabulary also do an async drift/path_provider data load that
    // won't resolve here either, so this only asserts that navigating to
    // each tab renders *something* (its AppBar title) without crashing —
    // not on their async-dependent content.
    await tester.pumpWidget(const ProviderScope(child: SignVoxApp()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Translate'), findsWidgets);
    expect(find.text('Teach'), findsOneWidget);
    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Teach'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.widgetWithText(AppBar, 'Teach'), findsOneWidget);

    await tester.tap(find.text('Vocabulary'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.widgetWithText(AppBar, 'Vocabulary'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });
}
