import 'dart:typed_data';

/// One tracked hand in a single camera frame: 21 landmarks x (x, y, z),
/// already normalized to [0,1] image space, upright and mirrored to match
/// the on-screen preview (see PLAN.md §3/§5.2).
class HandLandmarks {
  const HandLandmarks({
    required this.isLeft,
    required this.score,
    required this.landmarks,
  });

  factory HandLandmarks.fromMap(Map<Object?, Object?> map) {
    final rawLm = map['lm'];
    final Float32List lm = rawLm is Float32List
        ? rawLm
        : Float32List.fromList((rawLm as List).cast<double>());
    return HandLandmarks(
      isLeft: (map['hd'] as int) == 1,
      score: (map['score'] as num).toDouble(),
      landmarks: lm,
    );
  }

  final bool isLeft;
  final double score;

  /// 63 floats: 21 landmarks * (x, y, z), in that order.
  final Float32List landmarks;

  double x(int i) => landmarks[i * 3];
  double y(int i) => landmarks[i * 3 + 1];
  double z(int i) => landmarks[i * 3 + 2];
}

/// One event off the `signvox/landmarks` EventChannel: zero or more hands
/// detected in a single analyzed camera frame.
class LandmarkFrame {
  const LandmarkFrame({
    required this.timestampMs,
    required this.inferenceMs,
    required this.hands,
  });

  factory LandmarkFrame.fromMap(Map<Object?, Object?> map) {
    final rawHands = (map['hands'] as List).cast<Map<Object?, Object?>>();
    return LandmarkFrame(
      timestampMs: map['t'] as int,
      inferenceMs: (map['infMs'] as num).toDouble(),
      hands: rawHands.map(HandLandmarks.fromMap).toList(growable: false),
    );
  }

  final int timestampMs;
  final double inferenceMs;
  final List<HandLandmarks> hands;
}
