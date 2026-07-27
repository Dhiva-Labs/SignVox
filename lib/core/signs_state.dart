/// UI-facing snapshot of Signs mode: words already committed, plus a
/// rejected top-guess (if any) the user can tap to accept anyway — the
/// candidate bar from PLAN.md §4 (simplified to the single best guess
/// rather than a full top-3 ranking; see PLAN.md's P5 gotchas for why).
class SignsState {
  const SignsState({
    required this.sentence,
    this.candidateLabel,
    this.candidateConfidence = 0.0,
  });

  static const empty = SignsState(sentence: []);

  final List<String> sentence;
  final String? candidateLabel;

  /// `exp(-score / threshold)` for the rejected guess
  /// (PLAN_V2_RECOGNITION.md R4 step 5). A raw DTW distance is meaningless to
  /// a user deciding whether to tap-accept; a percentage is not.
  final double candidateConfidence;

  String get fullText => sentence.join(' ');
}
