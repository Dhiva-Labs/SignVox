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
}
