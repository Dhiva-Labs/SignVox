/// One entry in the Translate screen's candidate bar: a letter the model
/// currently thinks it might be, with its smoothed probability.
class LetterCandidate {
  const LetterCandidate(this.label, this.confidence);

  final String label;
  final double confidence;
}

/// UI-facing snapshot of Spell mode: words already committed to the
/// sentence, plus whatever's currently being spelled.
class SpellState {
  const SpellState({
    required this.sentence,
    required this.currentWord,
    this.candidateLabel,
    this.holdProgress = 0.0,
    this.candidates = const [],
    this.isTransitioning = false,
    this.suggestions = const [],
  });

  static const empty = SpellState(sentence: [], currentWord: '');

  final List<String> sentence;
  final String currentWord;

  /// The letter currently building toward a commit, if any.
  final String? candidateLabel;

  /// 0->1 progress of that letter's hold (PLAN_V2_RECOGNITION.md R3 step 7).
  /// The Translate screen draws this as a ring around the candidate chip:
  /// watching the commit build is what makes recognition *feel* responsive,
  /// separately from whether it picked the right letter.
  final double holdProgress;

  /// Smoothed top-3, best first — shown so a user who sees the wrong letter
  /// winning can tell whether the right one is a close second (adjust the hand)
  /// or nowhere (start over).
  final List<LetterCandidate> candidates;

  /// True while the hand is moving fast enough that the hold is frozen. The UI
  /// dims the ring rather than hiding it, so a paused ring reads as "hold
  /// still", not as a bug.
  final bool isTransitioning;

  /// One-tap completions of [currentWord], best first (empty when the word is
  /// empty or nothing matches). Tapping one commits the whole word instantly —
  /// the conversational-speed feature.
  final List<String> suggestions;

  String get fullText =>
      [...sentence, if (currentWord.isNotEmpty) currentWord].join(' ');
}
