import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../data/history_repository.dart';
import '../data/sign_repository.dart';
import '../engines/dtw_engine.dart';
import '../speech/tts_service.dart';
import 'landmark_frame.dart';
import 'motion_energy.dart';
import 'normalize.dart';
import 'resample.dart';
import 'signs_state.dart';

/// Bridges the word-sign recognition pipeline (PLAN.md §5.5 Signs mode) to
/// the UI: segments motion, resamples to 32 frames, runs 1-NN DTW against
/// every enabled taught sign, speaks an accepted match immediately, or
/// surfaces the top (rejected) guess as a tappable candidate.
///
/// Classification runs synchronously rather than via `Isolate.run` — it
/// fires once per *completed segment* (roughly once per sign, not every
/// frame), and the plan's own §6.3 estimate (~130k multiplies/exemplar) is
/// sub-millisecond for a realistic taught vocabulary; spawning a fresh
/// isolate per call would likely cost more than the computation itself.
/// Revisit only if a real device with a large vocabulary shows otherwise.
class SignsController {
  SignsController({
    required this.repository,
    required this.tts,
    this.history,
    DtwEngine? dtwEngine,
    MotionEnergySegmenter? segmenter,
    this.dominantIsLeft = false,
    this.speakPerWord = true,
  }) : dtwEngine = dtwEngine ?? const DtwEngine(),
       segmenter = segmenter ?? MotionEnergySegmenter();

  final SignRepository repository;
  final TtsService tts;
  final HistoryRepository? history;
  final DtwEngine dtwEngine;
  final MotionEnergySegmenter segmenter;

  /// Mutable so Settings can flip it live without recreating the controller.
  bool dominantIsLeft;

  /// If false, only [speakAll] speaks; each accepted sign no longer
  /// auto-speaks immediately (PLAN.md §4 screen 7). Mutable, same reason.
  bool speakPerWord;

  final ValueNotifier<SignsState> state = ValueNotifier(SignsState.empty);
  final List<String> _sentence = [];

  /// Cache of augmented exemplars, keyed by `signId:rawExemplarCount`.
  /// Rebuilding ~15 sequences per sign on every completed segment would be pure
  /// waste, and keying on the raw count means teaching another take for a sign
  /// invalidates its entry automatically rather than silently serving stale
  /// virtuals. [invalidateExemplars] is still there for wholesale changes
  /// (pack import, bulk delete).
  final Map<String, List<List<Float32List>>> _augmented = {};

  Future<void> onFrame(LandmarkFrame frame) async {
    final vector = buildTwoHandVector(
      frame.hands,
      dominantIsLeft: dominantIsLeft,
    );
    final segment = segmenter.addFrame(vector);
    if (segment == null) return;

    final resampled = resampleSequence(segment, 32);
    final byId = await repository.enabledSignsWithExemplars();
    if (byId.isEmpty) return;

    final signsById = <int, Sign>{};
    final exemplarsById = <int, List<List<Float32List>>>{};
    final thresholdsById = <int, double>{};
    byId.forEach((sign, exemplars) {
      signsById[sign.id] = sign;
      // Virtual exemplars are generated here rather than stored: they are cheap
      // to recreate, worthless to persist, and this way the drift schema needs
      // no migration (PLAN_V2_RECOGNITION.md R4 step 2).
      exemplarsById[sign.id] = _augmented.putIfAbsent(
        '${sign.id}:${exemplars.length}',
        () => augmentExemplars(exemplars),
      );
      thresholdsById[sign.id] = sign.threshold;
    });

    final match = dtwEngine.classify(resampled, exemplarsById, thresholdsById);
    if (match == null) return;

    final matchedSign = signsById[match.signId]!;
    if (match.accepted) {
      _commit(matchedSign);
    } else {
      state.value = SignsState(
        sentence: List.of(_sentence),
        candidateLabel: matchedSign.label,
        candidateConfidence: match.confidence,
      );
    }
  }

  /// Accepts the currently-shown candidate anyway (tap-to-force-commit).
  Future<void> acceptCandidate() async {
    final label = state.value.candidateLabel;
    if (label == null) return;
    final signs = await repository.allSigns();
    for (final summary in signs) {
      if (summary.sign.label == label) {
        _commit(summary.sign);
        return;
      }
    }
  }

  void _commit(Sign sign) {
    _sentence.add(sign.spokenText);
    if (speakPerWord) tts.speak(sign.spokenText);
    state.value = SignsState(sentence: List.of(_sentence));
  }

  /// Call after teaching, deleting, importing or enabling/disabling a sign.
  void invalidateExemplars() => _augmented.clear();

  void clear() {
    _sentence.clear();
    segmenter.reset();
    state.value = SignsState.empty;
  }

  void speakAll() {
    final text = state.value.fullText;
    tts.speak(text);
    history?.addEntry(text);
  }

  void dispose() {
    state.dispose();
  }
}
