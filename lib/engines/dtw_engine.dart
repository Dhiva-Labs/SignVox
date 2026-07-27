import 'dart:math' as math;
import 'dart:typed_data';

import '../core/resample.dart';

/// How much a z component counts in the frame distance, relative to x and y.
///
/// MediaPipe's z is estimated depth, not measured depth: it is noticeably
/// noisier than x/y and drifts with hand size and distance. At full weight it
/// contributed as much jitter to a DTW score as real hand motion did. Damping
/// it 0.5 matches what the letter model's v2 features do
/// (PLAN_V2_RECOGNITION.md R2/R4), so both recognizers now agree about how much
/// to trust depth.
const double dtwZWeight = 0.5;

/// Indices of the z components inside a 129-dim two-hand vector: the two
/// per-hand 63-blocks are (x,y,z) triples, and the trailing 3 dims (presence
/// flag + inter-wrist dx/dy) have no z at all.
bool _isZDim(int i) => i < 126 && i % 3 == 2;

double _euclidean(Float32List a, Float32List b) {
  double sum = 0;
  for (var i = 0; i < a.length; i++) {
    var d = a[i] - b[i];
    if (_isZDim(i)) d *= dtwZWeight;
    sum += d * d;
  }
  return math.sqrt(sum);
}

/// DTW distance between two equal-or-different-length sequences of feature
/// vectors, restricted to a Sakoe-Chiba band of [bandWidth] frames around
/// the diagonal (PLAN.md §6.3) — keeps cost roughly O(n*bandWidth) instead
/// of O(n²) and rules out degenerate alignments. Both sequences are 32
/// frames in normal use (segments are resampled to 32 before comparison —
/// see the Signs-mode decoder), so the band comfortably contains the
/// diagonal path in practice.
///
/// Returns path cost divided by sequence length, so scores are comparable
/// across calls regardless of length.
///
/// [abandonAbove] enables early abandonment (PLAN_V2_RECOGNITION.md R4 step 4):
/// pass the best score found so far and this returns [double.infinity] as soon
/// as no completion of the current alignment could beat it. Because every row's
/// minimum is a lower bound on the final normalized cost, abandoning is exact —
/// it never changes which exemplar wins, it just stops paying for exemplars that
/// have already lost. That is what keeps Signs mode fast as a taught vocabulary
/// grows from five signs to a few hundred.
double dtwDistance(
  List<Float32List> a,
  List<Float32List> b, {
  int bandWidth = 6,
  double abandonAbove = double.infinity,
}) {
  final n = a.length;
  final m = b.length;
  const inf = double.infinity;
  final abandonCost = abandonAbove.isFinite ? abandonAbove * n : inf;

  var prev = Float64List(m + 1)..fillRange(0, m + 1, inf);
  var curr = Float64List(m + 1);
  prev[0] = 0;

  for (var i = 1; i <= n; i++) {
    curr.fillRange(0, m + 1, inf);
    final jMin = math.max(1, i - bandWidth);
    final jMax = math.min(m, i + bandWidth);
    var rowMin = inf;
    for (var j = jMin; j <= jMax; j++) {
      final cost = _euclidean(a[i - 1], b[j - 1]);
      final best = math.min(prev[j], math.min(curr[j - 1], prev[j - 1]));
      final value = cost + best;
      curr[j] = value;
      if (value < rowMin) rowMin = value;
    }
    if (rowMin > abandonCost) return inf;
    final swap = prev;
    prev = curr;
    curr = swap;
  }
  return prev[m] / n;
}

/// Result of a 1-NN classification attempt against all enabled signs.
class DtwMatch {
  const DtwMatch({
    required this.signId,
    required this.score,
    required this.accepted,
    this.confidence = 0.0,
  });

  final int signId;
  final double score;
  final bool accepted;

  /// `exp(-score / threshold)`, clamped to [0,1] — a monotone, per-sign-scaled
  /// reading of the raw distance for the candidate bar
  /// (PLAN_V2_RECOGNITION.md R4 step 5). A raw DTW distance means nothing to a
  /// user; "82%" does.
  final double confidence;
}

/// Teach-mode word-sign recognizer (PLAN.md §6.3): no training needed, just
/// distance comparisons against exemplars recorded in the Teach wizard —
/// this is what makes Signs mode completable without a big labeled dataset.
/// Callers on the UI thread should run [classify] via `Isolate.run` (kept
/// out of this class so the core algorithm stays a plain, fast, synchronous,
/// easily-unit-tested function per the plan's "unit-test DTW with synthetic
/// sequences" instruction).
class DtwEngine {
  const DtwEngine({this.bandWidth = 6, this.rejectionMargin = 0.8});

  final int bandWidth;

  /// The best match must beat the runner-up (a different sign) by at least
  /// this fraction, or it's rejected even if under its own threshold — stops
  /// a mediocre match "winning" just because every sign scored badly.
  final double rejectionMargin;

  /// 1-NN search across every enabled sign's exemplars. Returns null only
  /// when there are no signs/exemplars to compare against at all.
  DtwMatch? classify(
    List<Float32List> query,
    Map<int, List<List<Float32List>>> exemplarsBySignId,
    Map<int, double> thresholdBySignId,
  ) {
    int? bestSignId;
    var bestScore = double.infinity;
    var secondBestScore = double.infinity;

    for (final entry in exemplarsBySignId.entries) {
      var bestForThisSign = double.infinity;
      for (final exemplar in entry.value) {
        // Abandon against the best *within this sign* as well as globally: both
        // bounds are valid, and the tighter one prunes more.
        final bound = math.min(bestForThisSign, secondBestScore);
        final score = dtwDistance(
          query,
          exemplar,
          bandWidth: bandWidth,
          abandonAbove: bound,
        );
        if (score < bestForThisSign) bestForThisSign = score;
      }
      if (bestForThisSign < bestScore) {
        secondBestScore = bestScore;
        bestScore = bestForThisSign;
        bestSignId = entry.key;
      } else if (bestForThisSign < secondBestScore) {
        secondBestScore = bestForThisSign;
      }
    }

    if (bestSignId == null || bestScore.isInfinite) return null;

    final threshold = thresholdBySignId[bestSignId] ?? double.infinity;
    final hasMargin =
        secondBestScore.isInfinite ||
        bestScore < rejectionMargin * secondBestScore;
    final confidence = threshold.isFinite && threshold > 0
        ? math.exp(-bestScore / threshold).clamp(0.0, 1.0)
        : 0.0;
    return DtwMatch(
      signId: bestSignId,
      score: bestScore,
      accepted: bestScore < threshold && hasMargin,
      confidence: confidence,
    );
  }

  /// Per-sign acceptance threshold from teach-time exemplar spread.
  ///
  /// v1.0 used mean + 2*stddev over all *pairwise* intra-class distances. With
  /// the wizard's 5 exemplars that is 10 numbers, and — worse — a pairwise
  /// distance is not the quantity [classify] actually compares against:
  /// classify takes the distance to the *nearest* exemplar. Those two
  /// distributions differ a lot, so the old threshold was systematically loose.
  ///
  /// This is a leave-one-out estimate (PLAN_V2_RECOGNITION.md R4 step 3): for
  /// each exemplar, the distance to its nearest *other* exemplar — exactly the
  /// statistic classify computes at recognition time — then mean + 2*stddev
  /// over those, with [floor] kept so a sign taught with unusually consistent
  /// samples doesn't end up with an unrealistically tight, fragile threshold.
  double computeThreshold(
    List<List<Float32List>> exemplars, {
    double floor = 0.15,
  }) {
    if (exemplars.length < 2) return floor;

    final nearest = <double>[];
    for (var i = 0; i < exemplars.length; i++) {
      var best = double.infinity;
      for (var j = 0; j < exemplars.length; j++) {
        if (i == j) continue;
        final d = dtwDistance(
          exemplars[i],
          exemplars[j],
          bandWidth: bandWidth,
          abandonAbove: best,
        );
        if (d < best) best = d;
      }
      if (best.isFinite) nearest.add(best);
    }
    if (nearest.isEmpty) return floor;

    final mean = nearest.reduce((a, b) => a + b) / nearest.length;
    final variance =
        nearest.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
        nearest.length;
    return math.max(floor, mean + 2 * math.sqrt(variance));
  }
}

/// Expands each recorded exemplar into itself plus [perExemplar] synthetic
/// variants (PLAN_V2_RECOGNITION.md R4 step 2).
///
/// Five hand-recorded exemplars is a thin basis for 1-NN, and the resulting
/// thresholds swing wildly with which five takes the user happened to record.
/// Time-warping (±[timeWarp]) and landmark noise (sigma [noise]) are the two
/// ways the *same* sign genuinely varies between performances, so synthesising
/// them gives both better nearest-neighbour coverage and a far steadier
/// threshold estimate.
///
/// Generated **in memory at load time on purpose**: the alternative was a drift
/// migration adding an `isVirtual` column, and virtual exemplars are cheap to
/// recreate and worthless to persist. The DB schema stays untouched.
List<List<Float32List>> augmentExemplars(
  List<List<Float32List>> exemplars, {
  int perExemplar = 2,
  double timeWarp = 0.15,
  double noise = 0.01,
  int seed = 7,
}) {
  if (exemplars.isEmpty || perExemplar <= 0) return exemplars;
  final rng = math.Random(seed);
  final out = <List<Float32List>>[];

  for (final exemplar in exemplars) {
    out.add(exemplar);
    if (exemplar.isEmpty) continue;
    final targetLength = exemplar.length;
    for (var k = 0; k < perExemplar; k++) {
      // Time warp: resample to a stretched/compressed length, then back to the
      // original length. The round trip is what actually shifts where each pose
      // falls in the sequence; resampling straight back would be a no-op.
      final factor = 1.0 + (rng.nextDouble() * 2 - 1) * timeWarp;
      final warpedLength = math.max(2, (targetLength * factor).round());
      final warped = resampleSequence(
        resampleSequence(exemplar, warpedLength),
        targetLength,
      );
      for (final frame in warped) {
        for (var i = 0; i < frame.length; i++) {
          if (frame[i] == 0.0 && i >= 63) {
            continue; // leave absent-hand padding alone
          }
          frame[i] += _gaussian(rng) * noise;
        }
      }
      out.add(warped);
    }
  }
  return out;
}

double _gaussian(math.Random rng) {
  // Box-Muller; one draw per call is fine at this volume.
  final u1 = rng.nextDouble().clamp(1e-9, 1.0);
  final u2 = rng.nextDouble();
  return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
}
