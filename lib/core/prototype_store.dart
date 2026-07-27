import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../engines/user_prototypes.dart';

/// Persistence for on-device personalisation (PLAN_V2_RECOGNITION.md R6).
///
/// A plain JSON file in the app's documents directory — no database table,
/// because there is exactly one of these per install, it is a few KB, and
/// "reset personalisation" should be a file delete rather than a migration.
/// It never leaves the device: the app declares no network permission at all,
/// which is the whole point of doing personalisation this way instead of
/// server-side.
const String kPrototypesFileName = 'letter_prototypes.json';

Future<File> _prototypesFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$kPrototypesFileName');
}

Future<UserPrototypes> loadUserPrototypes() async {
  try {
    final file = await _prototypesFile();
    if (!await file.exists()) return UserPrototypes();
    return UserPrototypes.decode(await file.readAsString());
  } catch (e) {
    // A corrupt prototypes file must never stop the app from recognising
    // anything — fall back to the un-personalised model.
    debugPrint('UserPrototypes: failed to load, continuing without them: $e');
    return UserPrototypes();
  }
}

Future<void> saveUserPrototypes(UserPrototypes prototypes) async {
  final file = await _prototypesFile();
  await file.writeAsString(prototypes.encode(), flush: true);
}

Future<void> deleteUserPrototypes() async {
  final file = await _prototypesFile();
  if (await file.exists()) await file.delete();
}
