import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/letter_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled letters_weights.json asset loads and runs without crashing', () async {
    final engine = await LetterEngine.load();
    // A zero vector isn't a real hand pose, but this only needs to prove the
    // asset parses and the forward pass runs end-to-end without throwing —
    // real accuracy depends on the model trained from the user's own Data
    // Lab recordings (this bundled asset is a placeholder, see PLAN.md P3).
    final prediction = engine.predict(Float32List(63));
    expect(prediction.label, isNotEmpty);
    expect(prediction.confidence, inInclusiveRange(0.0, 1.0));
  });
}
