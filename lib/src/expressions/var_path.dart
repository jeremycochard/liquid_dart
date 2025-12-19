import "../errors/liquid_error.dart";

sealed class PathSegment {}

class KeySegment extends PathSegment {
  final String key;
  KeySegment(this.key);
}

class IndexSegment extends PathSegment {
  final int index;
  IndexSegment(this.index);
}

class VarPath {
  final String root;
  final List<PathSegment> segments;

  VarPath({required this.root, required this.segments});

  static VarPath parse(String input) {
    final s = input.trim();
    if (s.isEmpty) {
      throw LiquidParseError("Empty output expression");
    }

    var i = 0;

    String readIdent() {
      if (i >= s.length) {
        throw LiquidParseError("Expected identifier in: $s");
      }
      final start = i;
      final first = s.codeUnitAt(i);
      final isFirstOk =
          (first >= 65 && first <= 90) ||
          (first >= 97 && first <= 122) ||
          first == 95;
      if (!isFirstOk) {
        throw LiquidParseError("Expected identifier in: $s");
      }
      i++;
      while (i < s.length) {
        final c = s.codeUnitAt(i);
        final ok =
            (c >= 65 && c <= 90) ||
            (c >= 97 && c <= 122) ||
            (c >= 48 && c <= 57) ||
            c == 95;
        if (!ok) break;
        i++;
      }
      return s.substring(start, i);
    }

    void skipSpaces() {
      while (i < s.length && s.codeUnitAt(i) <= 32) {
        i++;
      }
    }

    skipSpaces();
    final root = readIdent();
    final segments = <PathSegment>[];

    while (true) {
      skipSpaces();
      if (i >= s.length) break;

      final ch = s[i];
      if (ch == ".") {
        i++;
        skipSpaces();
        final name = readIdent();
        segments.add(KeySegment(name));
        continue;
      }

      if (ch == "[") {
        i++;
        skipSpaces();
        if (i >= s.length) {
          throw LiquidParseError("Unclosed bracket in: $s");
        }

        PathSegment seg;

        final q = s[i];
        if (q == '"' || q == "'") {
          i++;
          final start = i;
          while (i < s.length && s[i] != q) {
            i++;
          }
          if (i >= s.length) {
            throw LiquidParseError("Unclosed string in: $s");
          }
          final key = s.substring(start, i);
          i++; // closing quote
          seg = KeySegment(key);
        } else {
          final start = i;
          var isDigits = true;
          while (i < s.length && s[i] != "]" && s.codeUnitAt(i) > 32) {
            final c = s.codeUnitAt(i);
            if (c < 48 || c > 57) isDigits = false;
            i++;
          }
          final raw = s.substring(start, i).trim();
          if (raw.isEmpty) {
            throw LiquidParseError("Empty bracket access in: $s");
          }
          if (isDigits) {
            seg = IndexSegment(int.parse(raw));
          } else {
            seg = KeySegment(raw);
          }
        }

        skipSpaces();
        if (i >= s.length || s[i] != "]") {
          throw LiquidParseError("Unclosed bracket in: $s");
        }
        i++; // ]
        segments.add(seg);
        continue;
      }

      break;
    }

    skipSpaces();
    if (i < s.length) {
      throw LiquidParseError("Unsupported expression: $s");
    }

    return VarPath(root: root, segments: segments);
  }

  @override
  String toString() => segments.isEmpty ? root : "$root[...]";
}
