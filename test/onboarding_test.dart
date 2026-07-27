import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_vox/ui/onboarding/onboarding_screen.dart';

void main() {
  // Onboarding's second page asks for camera permission via permission_handler
  // (a courtesy pre-ask, not a gate). Mock its channel so that request
  // resolves instead of throwing MissingPluginException in this bare test
  // environment — mirrors what the real Android platform channel returns.
  const permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionChannel,
      (call) async {
        if (call.method == 'requestPermissions') {
          final codes = (call.arguments as List).cast<int>();
          return {for (final code in codes) code: 1}; // 1 == PermissionStatus.granted
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      permissionChannel,
      null,
    );
  });

  testWidgets('shows onboarding on first run, then reveals the child after completion', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: OnboardingGate(child: Text('Main app'))),
    );
    await tester.pump();

    expect(find.text('Sign, and SignVox speaks for you'), findsOneWidget);
    expect(find.text('Main app'), findsNothing);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('The camera reads your hands'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Hold the phone at chest height'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Main app'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete_v1'), isTrue);
  });

  testWidgets('skips onboarding entirely on a return visit', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_complete_v1': true});

    await tester.pumpWidget(
      const MaterialApp(home: OnboardingGate(child: Text('Main app'))),
    );
    await tester.pump();

    expect(find.text('Main app'), findsOneWidget);
    expect(find.text('Sign, and SignVox speaks for you'), findsNothing);
  });
}
