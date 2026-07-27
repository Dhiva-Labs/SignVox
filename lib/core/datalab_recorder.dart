import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes Data Lab recordings to CSV (PLAN.md §4/§9): one file per label,
/// each row = 21 normalized landmarks (x,y,z) + the label, in the exact
/// column layout `tools/train_letters.py` expects. Stored under the app's
/// external files dir so `adb pull` can grab the whole folder without extra
/// storage permissions (scoped storage already grants this app that path).
class DataLabRecorder {
  static final _columns = [
    for (var i = 0; i < 21; i++) ...['lm${i}_x', 'lm${i}_y', 'lm${i}_z'],
    'label',
  ];

  Future<Directory> _datalabDir() async {
    final base = await getExternalStorageDirectory();
    final dir = Directory('${base!.path}/SignVox/datalab');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _fileFor(String label) async {
    final dir = await _datalabDir();
    return File('${dir.path}/$label.csv');
  }

  /// Rows already recorded for [label] (0 if the file doesn't exist yet) —
  /// used to show recording progress across sessions.
  Future<int> countExisting(String label) async {
    final file = await _fileFor(label);
    if (!await file.exists()) return 0;
    final lines = await file.readAsLines();
    return lines.isEmpty ? 0 : lines.length - 1; // minus header
  }

  /// Appends one row per normalized 63-float hand sample, creating the file
  /// (with header) on first write.
  Future<void> appendSamples(
    String label,
    List<Float32List> normalizedSamples,
  ) async {
    final file = await _fileFor(label);
    final isNew = !await file.exists();
    final sink = file.openWrite(mode: FileMode.append);
    try {
      if (isNew) {
        sink.writeln(_columns.join(','));
      }
      for (final sample in normalizedSamples) {
        sink.writeln('${sample.join(',')},$label');
      }
    } finally {
      await sink.close();
    }
  }

  Future<String> datalabPath() async => (await _datalabDir()).path;
}
