import 'package:flutter/services.dart' show rootBundle;

/// Offline word completion for Spell mode.
///
/// Fingerspelling a whole word letter-by-letter is the slowest part of holding
/// a real conversation. After the first letter or two, the word the user wants
/// is usually near the top of an English frequency list — surfacing the top
/// completions as one-tap chips turns a five-letter, five-hold word into two
/// holds and a tap. The list (assets/wordlist/en_common.txt, ~8k words, MIT —
/// see the LICENSE next to it) is bundled, so this stays fully offline like
/// everything else.
class WordSuggester {
  WordSuggester.fromWords(List<String> frequencyOrdered)
    : _alphabetical = [
        for (var i = 0; i < frequencyOrdered.length; i++)
          (frequencyOrdered[i].toUpperCase(), i),
      ]..sort((a, b) => a.$1.compareTo(b.$1));

  /// (word, frequencyRank), sorted alphabetically so a prefix maps to one
  /// contiguous range findable by binary search.
  final List<(String, int)> _alphabetical;

  static Future<WordSuggester> load({
    String assetPath = 'assets/wordlist/en_common.txt',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    return WordSuggester.fromWords([
      for (final line in raw.split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    ]);
  }

  /// Most frequent words starting with (but not equal to) [prefix],
  /// best first. Empty for an empty prefix.
  List<String> suggest(String prefix, {int max = 3}) {
    final p = prefix.toUpperCase();
    if (p.isEmpty) return const [];

    var lo = 0, hi = _alphabetical.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_alphabetical[mid].$1.compareTo(p) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }

    final inRange = <(String, int)>[];
    for (var i = lo; i < _alphabetical.length; i++) {
      final (word, rank) = _alphabetical[i];
      if (!word.startsWith(p)) break;
      if (word == p) continue;
      inRange.add((word, rank));
    }
    inRange.sort((a, b) => a.$2.compareTo(b.$2));
    return [for (final e in inRange.take(max)) e.$1];
  }

  /// Common words rank better than this can be offered as auto-corrections;
  /// beyond it, an obscure "fix" is more likely wrong than the user's word.
  static const _correctionRankCeiling = 4000;

  /// The auto-correction for [word], or null when the word is already known,
  /// too short to judge, or nothing common is one edit away.
  ///
  /// This is the word-level answer to letter-level confusion: the model
  /// mistaking one M for an N turns HELLO into HELLN exactly once per word,
  /// and one Damerau edit (substitution, insertion, deletion, or adjacent
  /// swap) against a frequency list repairs it before it is ever spoken.
  String? correct(String word) {
    final w = word.toUpperCase();
    if (w.length < 3 || _contains(w)) return null;

    String? best;
    var bestRank = _correctionRankCeiling;
    for (final (candidate, rank) in _alphabetical) {
      if (rank >= bestRank) continue;
      if ((candidate.length - w.length).abs() > 1) continue;
      if (_withinOneEdit(w, candidate)) {
        best = candidate;
        bestRank = rank;
      }
    }
    return best;
  }

  bool _contains(String word) {
    var lo = 0, hi = _alphabetical.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final cmp = _alphabetical[mid].$1.compareTo(word);
      if (cmp == 0) return true;
      if (cmp < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return false;
  }

  /// Damerau-Levenshtein distance <= 1, specialized: one substitution, one
  /// adjacent transposition, or one insertion/deletion.
  static bool _withinOneEdit(String a, String b) {
    final la = a.length, lb = b.length;
    if (la == lb) {
      var first = -1, second = -1;
      for (var i = 0; i < la; i++) {
        if (a.codeUnitAt(i) != b.codeUnitAt(i)) {
          if (first < 0) {
            first = i;
          } else if (second < 0) {
            second = i;
          } else {
            return false;
          }
        }
      }
      if (first < 0) return false; // identical — caller filters exact matches
      if (second < 0) return true; // one substitution
      return second == first + 1 &&
          a.codeUnitAt(first) == b.codeUnitAt(second) &&
          a.codeUnitAt(second) == b.codeUnitAt(first); // adjacent swap
    }
    // Length differs by one: a single insertion/deletion.
    final (shorter, longer) = la < lb ? (a, b) : (b, a);
    var i = 0, j = 0;
    var skipped = false;
    while (i < shorter.length) {
      if (shorter.codeUnitAt(i) == longer.codeUnitAt(j)) {
        i++;
        j++;
      } else {
        if (skipped) return false;
        skipped = true;
        j++;
      }
    }
    return true;
  }
}
