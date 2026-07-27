import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // The bundled Inter typeface ships under the SIL OFL 1.1; surfacing it in
  // the in-app license page keeps the About screen's licensing story
  // complete, same as the Piper voice and HandLandmarker model.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Inter font'], text);
  });
  runApp(const ProviderScope(child: SignVoxApp()));
}
