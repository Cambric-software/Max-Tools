/// String-distance helpers used by the command palette to recover from typos.
///
/// Kept separate and dependency-free so the correction behaviour is easy to
/// test and easy to reason about.
library;

/// Levenshtein edit distance between [a] and [b].
///
/// Returns the number of single-character edits (insert, delete, substitute)
/// needed to turn [a] into [b].
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitutionCost = a[i] == b[j] ? 0 : 1;
      current[j + 1] = _min3(
        current[j] + 1, // insertion
        previous[j + 1] + 1, // deletion
        previous[j] + substitutionCost, // substitution
      );
    }
    final swap = previous;
    previous = current;
    current = swap;
  }
  return previous[b.length];
}

/// Damerau-Levenshtein distance: like [levenshtein] but counts a swapped pair
/// of adjacent characters as one edit, so "teh" -> "the" costs 1 not 2.
int damerauLevenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  final rows = a.length + 1;
  final columns = b.length + 1;
  final distance = List.generate(
    rows,
    (_) => List<int>.filled(columns, 0),
  );
  for (var i = 0; i < rows; i++) {
    distance[i][0] = i;
  }
  for (var j = 0; j < columns; j++) {
    distance[0][j] = j;
  }

  for (var i = 1; i < rows; i++) {
    for (var j = 1; j < columns; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var value = _min3(
        distance[i - 1][j] + 1,
        distance[i][j - 1] + 1,
        distance[i - 1][j - 1] + cost,
      );
      if (i > 1 &&
          j > 1 &&
          a[i - 1] == b[j - 2] &&
          a[i - 2] == b[j - 1]) {
        final transposition = distance[i - 2][j - 2] + 1;
        if (transposition < value) value = transposition;
      }
      distance[i][j] = value;
    }
  }
  return distance[a.length][b.length];
}

/// Edit distance that treats transpositions as one mistake.
///
/// The variant the palette actually uses, because transposed letters are the
/// most common human typo.
int editDistance(String a, String b) => damerauLevenshtein(
      a.toLowerCase(),
      b.toLowerCase(),
    );

/// Similarity in the range 0.0 (nothing alike) to 1.0 (identical).
///
/// Uses `1 - distance / longest`, so a short word that shares a long prefix
/// scores lower than one that genuinely matches.
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 1;
  return 1 - (editDistance(a, b) / longest);
}

/// Whether [candidate] is close enough to [word] to be offered as a fix.
///
/// The allowance scales with word length: short words tolerate one mistake,
/// longer ones tolerate two. Longer typos are left alone rather than "corrected"
/// into a different word.
bool isTypoOf(String word, String candidate, {int? maxDistance}) {
  final allowance = maxDistance ??
      (word.length <= 4
          ? 1
          : word.length <= 7
              ? 2
              : 3);
  if (word == candidate) return true;
  if (word.length - candidate.length > allowance) return false;
  if (candidate.length - word.length > allowance) return false;
  return editDistance(word, candidate) <= allowance;
}

int _min3(int a, int b, int c) {
  var smallest = a;
  if (b < smallest) smallest = b;
  if (c < smallest) smallest = c;
  return smallest;
}
