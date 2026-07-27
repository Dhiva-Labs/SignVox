/// Rolling debug stats for the FPS/latency HUD (PLAN.md §4/§11). Updated at
/// a throttled rate — separate from the per-frame [LandmarkFrame] notifier
/// that drives the overlay repaint, so the HUD text doesn't rebuild 30x/sec.
class VisionStats {
  const VisionStats({
    required this.fps,
    required this.lastInferenceMs,
    required this.handCount,
    this.normalizedIndexTipY,
  });

  static const zero = VisionStats(fps: 0, lastInferenceMs: 0, handCount: 0);

  final double fps;
  final double lastInferenceMs;
  final int handCount;

  /// Normalized (translation/scale/mirror-invariant) y of the index
  /// fingertip (landmark 8) for the first tracked hand, or null if no hand
  /// is present. Surfaced on the debug HUD so normalization can be watched
  /// live (PLAN.md P2 verify step) — it should hold steady for a held pose
  /// regardless of how far the hand is from the camera.
  final double? normalizedIndexTipY;
}
