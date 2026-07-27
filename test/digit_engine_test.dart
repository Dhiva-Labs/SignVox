import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sign_vox/engines/digit_engine.dart';

/// Schematic normalized hands (wrist at origin, wrist->middle-MCP ~= 1, image
/// convention: fingers point toward negative y), the same hand-crafted-fixture
/// approach normalize_test.dart uses. Only the joints the rules read need to
/// be anatomically meaningful; intermediate joints are interpolated.
Float32List hand({
  required bool indexExt,
  required bool middleExt,
  required bool ringExt,
  required bool pinkyExt,
  (double, double)? thumbTip, // default: tucked against the palm
  (double, double)? indexTipOverride,
  (double, double)? middleTipOverride,
  (double, double)? ringTipOverride,
  (double, double)? pinkyTipOverride,
}) {
  final n = Float32List(63);
  void put(int i, double x, double y) {
    n[i * 3] = x;
    n[i * 3 + 1] = y;
    n[i * 3 + 2] = 0;
  }

  const mcps = {
    5: (0.35, -1.0),
    9: (0.12, -1.02),
    13: (-0.12, -1.0),
    17: (-0.35, -0.95),
  };

  put(0, 0, 0); // wrist
  // Thumb chain — only the tip matters to the rules.
  put(1, 0.30, -0.30);
  put(2, 0.50, -0.50);
  put(3, 0.60, -0.70);
  final t = thumbTip ?? (0.30, -0.85);
  put(4, t.$1, t.$2);

  void finger(int mcp, bool extended, (double, double)? tipOverride) {
    final (mx, my) = mcps[mcp]!;
    final scale = extended ? 1.85 : 1.0;
    final tip = tipOverride ?? (mx * scale, my * scale);
    put(mcp, mx, my);
    // PIP / DIP interpolated along the way.
    put(mcp + 1, mx + (tip.$1 - mx) / 3, my + (tip.$2 - my) / 3);
    put(mcp + 2, mx + 2 * (tip.$1 - mx) / 3, my + 2 * (tip.$2 - my) / 3);
    put(mcp + 3, tip.$1, tip.$2);
  }

  finger(5, indexExt, indexTipOverride);
  finger(9, middleExt, middleTipOverride);
  finger(13, ringExt, ringTipOverride);
  finger(17, pinkyExt, pinkyTipOverride);
  return n;
}

const thumbOut = (1.10, -1.25);

void main() {
  final engine = DigitEngine();

  void expectDigit(String digit, Float32List pose, {double atLeast = 0.8}) {
    final p = engine.topOf(engine.probabilities(pose));
    expect(p.label, digit, reason: 'expected $digit, got ${p.label}');
    expect(p.confidence, greaterThan(atLeast),
        reason: '$digit confidence ${p.confidence}');
  }

  test('1: index only, thumb tucked', () {
    expectDigit(
      '1',
      hand(indexExt: true, middleExt: false, ringExt: false, pinkyExt: false),
    );
  });

  test('2: spread V with thumb tucked', () {
    expectDigit(
      '2',
      hand(
        indexExt: true,
        middleExt: true,
        ringExt: false,
        pinkyExt: false,
        indexTipOverride: (0.75, -1.80),
        middleTipOverride: (0.05, -1.85),
      ),
    );
  });

  test('3: index + middle + thumb out', () {
    expectDigit(
      '3',
      hand(
        indexExt: true,
        middleExt: true,
        ringExt: false,
        pinkyExt: false,
        thumbTip: thumbOut,
      ),
    );
  });

  test('4 vs 5: four fingers, thumb decides', () {
    expectDigit(
      '4',
      hand(indexExt: true, middleExt: true, ringExt: true, pinkyExt: true),
    );
    expectDigit(
      '5',
      hand(
        indexExt: true,
        middleExt: true,
        ringExt: true,
        pinkyExt: true,
        thumbTip: thumbOut,
      ),
    );
  });

  test('6/7/8/9: thumb touches pinky/ring/middle/index', () {
    const touchPoint = (0.35, -1.15);
    expectDigit(
      '6',
      hand(
        indexExt: true,
        middleExt: true,
        ringExt: true,
        pinkyExt: false,
        thumbTip: touchPoint,
        pinkyTipOverride: (0.37, -1.16),
      ),
    );
    expectDigit(
      '7',
      hand(
        indexExt: true,
        middleExt: true,
        ringExt: false,
        pinkyExt: true,
        thumbTip: touchPoint,
        ringTipOverride: (0.37, -1.16),
      ),
    );
    expectDigit(
      '8',
      hand(
        indexExt: true,
        middleExt: false,
        ringExt: true,
        pinkyExt: true,
        thumbTip: touchPoint,
        middleTipOverride: (0.37, -1.16),
      ),
    );
    expectDigit(
      '9',
      hand(
        indexExt: false,
        middleExt: true,
        ringExt: true,
        pinkyExt: true,
        thumbTip: touchPoint,
        indexTipOverride: (0.37, -1.16),
      ),
    );
  });

  test('0: all fingertips ring onto the thumb', () {
    const c = (0.30, -1.10);
    expectDigit(
      '0',
      hand(
        indexExt: false,
        middleExt: false,
        ringExt: false,
        pinkyExt: false,
        thumbTip: c,
        indexTipOverride: (0.32, -1.12),
        middleTipOverride: (0.28, -1.13),
        ringTipOverride: (0.31, -1.07),
        pinkyTipOverride: (0.27, -1.09),
      ),
      atLeast: 0.6,
    );
  });

  test('a plain fist (letter A/S territory) reads as none, not a digit', () {
    final p = engine.topOf(
      engine.probabilities(
        hand(indexExt: false, middleExt: false, ringExt: false, pinkyExt: false),
      ),
    );
    expect(p.label, 'none');
  });

  test('letter-ensemble blend lifts the identical shapes', () {
    // A weak geometric 9 plus a confident letter-F opinion must read as 9.
    final weakNine = hand(
      indexExt: false,
      middleExt: true,
      ringExt: true,
      pinkyExt: true,
      thumbTip: (0.35, -1.15),
      indexTipOverride: (0.55, -1.30), // not quite touching the thumb
    );
    final letterLabels = ['F', 'O', 'V', 'W'];
    final letterProbs = Float32List.fromList([0.9, 0.02, 0.02, 0.02]);
    final p = engine.topOf(
      engine.probabilities(
        weakNine,
        letterProbs: letterProbs,
        letterLabels: letterLabels,
      ),
    );
    expect(p.label, '9');
    expect(p.confidence, greaterThan(0.6));
  });
}
