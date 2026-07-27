import 'package:flutter/foundation.dart';

import '../data/history_repository.dart';
import '../engines/decoder.dart';
import '../engines/digit_engine.dart';
import '../engines/letter_engine.dart';
import '../engines/prob_smoother.dart';
import '../engines/word_suggester.dart';
import '../speech/tts_service.dart';
import 'landmark_frame.dart';
import 'normalize.dart';
import 'spell_state.dart';

/// Bridges the letter-recognition pipeline (PLAN.md §5.5 Spell mode) to the
/// UI: feed it landmark frames, it runs LetterEngine + SpellDecoder, speaks
/// each committed word immediately (so speaking overlaps continued signing —
/// PLAN.md's smoothness requirement), and publishes [state] for the
/// sentence-strip widget.
///
/// v1.1 inserts two stages between the model and the decoder
/// (PLAN_V2_RECOGNITION.md R3): a [ProbSmoother] over the whole probability
/// vector, and a [HandVelocityGate] that tells the decoder when the hand is
/// mid-transition. Both are per-frame and allocation-free (R5) — the
/// normalized-hand buffer below is reused rather than reallocated every frame.
class SpellController {
  SpellController({
    required this.letterEngine,
    required this.tts,
    this.history,
    this.suggester,
    this.digitEngine,
    this.leftHandedMode = false,
    this.speakPerWord = true,
    SpellDecoder? decoder,
    ProbSmoother? smoother,
    HandVelocityGate? velocityGate,
    this.presenceThreshold = 0.5,
  }) : decoder = decoder ?? SpellDecoder(),
       smoother = smoother ?? ProbSmoother(),
       velocityGate = velocityGate ?? HandVelocityGate();

  final LetterEngine letterEngine;
  final SpellDecoder decoder;
  final ProbSmoother smoother;
  final HandVelocityGate velocityGate;
  final TtsService tts;
  final HistoryRepository? history;

  /// Optional word completion for the suggestion chips; null = feature off.
  final WordSuggester? suggester;

  /// v1.3: rule-based 0-9 recognizer for Numbers mode; null = mode unavailable.
  final DigitEngine? digitEngine;

  bool _digitsMode = false;

  /// True while the UI's ABC/123 switch is on 123 — the frame pipeline then
  /// classifies digits (geometry + letter-ensemble blend for the shapes ASL
  /// shares between digits and letters) instead of letters.
  bool get digitsMode => _digitsMode;

  void setDigitsMode(bool enabled) {
    if (_digitsMode == enabled || (enabled && digitEngine == null)) return;
    _digitsMode = enabled;
    // The class vector changes size/meaning; carrying an EMA across would
    // blend letter mass into digit slots.
    smoother.reset();
    _publish();
  }

  /// MediaPipe hand score below which the frame is treated as no-hand
  /// (PLAN_V2_RECOGNITION.md R3 step 6). A barely-tracked hand produces
  /// garbage landmarks, and garbage landmarks produce confident wrong letters.
  final double presenceThreshold;

  /// PLAN.md §5.2 — which tracked hand to read when both are visible.
  /// Mutable so Settings can flip it live without recreating the controller.
  bool leftHandedMode;

  /// If false, only [speakAll] speaks; committed words no longer
  /// auto-speak one at a time (PLAN.md §4 screen 7). Mutable, same reason.
  bool speakPerWord;

  /// v1.2: repair a pause/space-committed word that is one edit from a common
  /// English word before it is spoken (needs [suggester]). Mutable so Settings
  /// can flip it live.
  bool autocorrect = true;

  final ValueNotifier<SpellState> state = ValueNotifier(SpellState.empty);
  final List<String> _sentence = [];
  final Float32List _normalized = Float32List(63);

  // Suggestions are recomputed only when the in-progress word actually
  // changes — _publish runs every frame (hold ring), and running a prefix
  // search 30×/s for an unchanged prefix would be pure waste.
  String _suggestPrefix = '';
  List<String> _suggestions = const [];

  void onFrame(LandmarkFrame frame) {
    LetterPrediction? prediction;
    var transitioning = false;
    List<LetterCandidate> candidates = const [];

    final hand = _pickHand(frame);
    if (hand != null) {
      normalizeHand(hand, out: _normalized);
      transitioning = velocityGate.addFrame(_normalized);
      final letterProbs = letterEngine.probabilities(_normalized);
      final digits = _digitsMode ? digitEngine : null;
      if (digits != null) {
        final smoothed = smoother.add(
          digits.probabilities(
            _normalized,
            letterProbs: letterProbs,
            letterLabels: letterEngine.labels,
          ),
        );
        prediction = digits.topOf(smoothed);
      } else {
        prediction = letterEngine.topOf(smoother.add(letterProbs));
      }
      candidates = _candidatesOf(prediction);
    } else {
      smoother.reset();
      velocityGate.reset();
    }

    final result = decoder.addPrediction(
      prediction,
      DateTime.now(),
      isTransitioning: transitioning,
    );

    if (result.committedWord != null) {
      final word = _finalizeWord(result.committedWord!);
      _sentence.add(word);
      if (speakPerWord) tts.speak(word);
    }
    // Publish every frame now, not only on commits: the hold ring and the
    // candidate bar are live indicators and would otherwise sit frozen between
    // commits, which reads as the app having hung.
    _publish(candidates: candidates, isTransitioning: transitioning);
  }

  HandLandmarks? _pickHand(LandmarkFrame frame) {
    HandLandmarks? fallback;
    for (final h in frame.hands) {
      if (h.score < presenceThreshold) continue;
      if (h.isLeft == leftHandedMode) return h;
      fallback ??= h;
    }
    return fallback;
  }

  List<LetterCandidate> _candidatesOf(LetterPrediction p) => [
    LetterCandidate(p.label, p.confidence),
    if (p.runnerUpLabel != null)
      LetterCandidate(p.runnerUpLabel!, p.runnerUpConfidence),
    if (p.thirdLabel != null) LetterCandidate(p.thirdLabel!, p.thirdConfidence),
  ];

  void speakAll() {
    final text = state.value.fullText;
    tts.speak(text);
    history?.addEntry(text);
  }

  void backspace() {
    if (decoder.currentWord.isNotEmpty) {
      decoder.removeLastLetter();
    } else if (_sentence.isNotEmpty) {
      _sentence.removeLast();
    }
    _publish();
  }

  /// Force-commits the in-progress word into the sentence, as if a pause
  /// had happened — lets the next letters start a fresh word on demand.
  void addSpace() {
    if (decoder.currentWord.isEmpty) return;
    _sentence.add(_finalizeWord(decoder.currentWord));
    decoder.reset();
    smoother.reset();
    _publish();
  }

  /// Applies word-level auto-correction (when enabled) to a spelled word at
  /// the moment it leaves the compose line. Suggestion taps skip this — those
  /// words come straight from the dictionary.
  String _finalizeWord(String word) {
    if (!autocorrect) return word;
    return suggester?.correct(word) ?? word;
  }

  /// Commits a tapped suggestion as the whole word — replaces whatever was
  /// spelled so far and speaks it immediately, so a conversation doesn't wait
  /// for the remaining letters or the end-of-word pause.
  void acceptSuggestion(String word) {
    if (word.isEmpty) return;
    _sentence.add(word);
    decoder.reset();
    smoother.reset();
    if (speakPerWord) tts.speak(word);
    _publish();
  }

  void clear() {
    _sentence.clear();
    decoder.reset();
    smoother.reset();
    velocityGate.reset();
    _publish();
  }

  void _publish({
    List<LetterCandidate> candidates = const [],
    bool isTransitioning = false,
  }) {
    final word = decoder.currentWord;
    if (word != _suggestPrefix) {
      _suggestPrefix = word;
      _suggestions = suggester?.suggest(word) ?? const [];
    }
    state.value = SpellState(
      sentence: List.of(_sentence),
      currentWord: word,
      candidateLabel: decoder.candidateLabel,
      holdProgress: decoder.holdProgress,
      candidates: candidates,
      isTransitioning: isTransitioning,
      suggestions: _suggestions,
    );
  }

  void dispose() {
    state.dispose();
  }
}
