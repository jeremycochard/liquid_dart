import "../errors/liquid_error.dart";
import "../expressions/expression.dart";
import "../runtime/render_context.dart";

enum CompareOp { eq, neq, gt, gte, lt, lte, contains }

sealed class Condition {
  bool eval(RenderContext ctx);

  static Condition parse(String input) {
    var s = input.trim();
    if (s.isEmpty) throw LiquidParseError("Empty condition");

    s = _stripOuterParens(s);

    // or
    final orParts = _splitByKeyword(s, "or");
    if (orParts.length > 1) {
      return OrCondition(orParts.map(parse).toList(growable: false));
    }

    // and
    final andParts = _splitByKeyword(s, "and");
    if (andParts.length > 1) {
      return AndCondition(andParts.map(parse).toList(growable: false));
    }

    // not
    final notRest = _consumeLeadingKeyword(s, "not");
    if (notRest != null) {
      return NotCondition(parse(notRest));
    }

    // comparison (top-level)
    final comp = _splitComparison(s);
    if (comp != null) {
      final (leftRaw, op, rightRaw) = comp;
      return CompareCondition(
        left: Expression.parse(leftRaw),
        op: op,
        right: Expression.parse(rightRaw),
      );
    }

    // truthy
    return TruthyCondition(Expression.parse(s));
  }

  static String _stripOuterParens(String s) {
    var cur = s.trim();
    while (cur.startsWith("(") && cur.endsWith(")")) {
      final inner = cur.substring(1, cur.length - 1).trim();
      if (_isBalancedParens(inner)) {
        cur = inner;
      } else {
        break;
      }
    }
    return cur;
  }

  static bool _isBalancedParens(String s) {
    var depth = 0;
    String? quote;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (quote != null) {
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        continue;
      }
      if (ch == "(") depth++;
      if (ch == ")") {
        depth--;
        if (depth < 0) return false;
      }
    }
    return depth == 0;
  }

  static List<String> _splitByKeyword(String s, String kw) {
    final parts = <String>[];
    final buf = StringBuffer();

    var depth = 0;
    String? quote;

    bool isWordChar(String c) {
      final cu = c.codeUnitAt(0);
      final isAlphaNum =
          (cu >= 65 && cu <= 90) ||
          (cu >= 97 && cu <= 122) ||
          (cu >= 48 && cu <= 57) ||
          cu == 95;
      return isAlphaNum;
    }

    for (var i = 0; i < s.length; i++) {
      final ch = s[i];

      if (quote != null) {
        if (ch == quote) quote = null;
        buf.write(ch);
        continue;
      }

      if (ch == "'" || ch == '"') {
        quote = ch;
        buf.write(ch);
        continue;
      }

      if (ch == "(") {
        depth++;
        buf.write(ch);
        continue;
      }
      if (ch == ")") {
        depth--;
        buf.write(ch);
        continue;
      }

      if (depth == 0) {
        // detect keyword with word boundaries
        if (i + kw.length <= s.length && s.substring(i, i + kw.length) == kw) {
          final before = i == 0 ? null : s[i - 1];
          final after = (i + kw.length) >= s.length ? null : s[i + kw.length];

          final beforeOk = before == null || !isWordChar(before);
          final afterOk = after == null || !isWordChar(after);

          if (beforeOk && afterOk) {
            final left = buf.toString().trim();
            if (left.isNotEmpty) parts.add(left);
            buf.clear();
            i += kw.length - 1;
            continue;
          }
        }
      }

      buf.write(ch);
    }

    final last = buf.toString().trim();
    if (last.isNotEmpty) parts.add(last);
    return parts;
  }

  static String? _consumeLeadingKeyword(String s, String kw) {
    var cur = s.trimLeft();
    if (!cur.startsWith(kw)) return null;

    final after = cur.substring(kw.length);
    // require boundary: either end or whitespace or '('
    if (after.isNotEmpty) {
      final c = after[0];
      final isBoundary = c.trim().isEmpty || c == "(";
      if (!isBoundary) return null;
    }
    return after.trim();
  }

  static (String, CompareOp, String)? _splitComparison(String s) {
    final ops = <(String, CompareOp)>[
      ("==", CompareOp.eq),
      ("!=", CompareOp.neq),
      (">=", CompareOp.gte),
      ("<=", CompareOp.lte),
      (">", CompareOp.gt),
      ("<", CompareOp.lt),
    ];

    (String, CompareOp, String)? best;

    // keyword operator: contains
    final contains = _findTopLevelKeyword(s, "contains");
    if (contains != null) {
      final (start, end) = contains;
      final left = s.substring(0, start).trim();
      final right = s.substring(end).trim();
      if (left.isEmpty || right.isEmpty) {
        throw LiquidParseError("Invalid contains condition: $s");
      }
      return (left, CompareOp.contains, right);
    }

    final pos = _findTopLevelOperator(
      s,
      ops.map((e) => e.$1).toList(growable: false),
    );
    if (pos != null) {
      final (idx, opStr) = pos;
      final left = s.substring(0, idx).trim();
      final right = s.substring(idx + opStr.length).trim();
      if (left.isEmpty || right.isEmpty) {
        throw LiquidParseError("Invalid comparison condition: $s");
      }
      final op = ops.firstWhere((e) => e.$1 == opStr).$2;
      best = (left, op, right);
    }

    return best;
  }

  static (int, String)? _findTopLevelOperator(
    String s,
    List<String> operators,
  ) {
    var depth = 0;
    String? quote;

    for (var i = 0; i < s.length; i++) {
      final ch = s[i];

      if (quote != null) {
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        continue;
      }
      if (ch == "(") {
        depth++;
        continue;
      }
      if (ch == ")") {
        depth--;
        continue;
      }
      if (depth != 0) continue;

      for (final op in operators) {
        if (i + op.length <= s.length && s.substring(i, i + op.length) == op) {
          return (i, op);
        }
      }
    }
    return null;
  }

  static (int, int)? _findTopLevelKeyword(String s, String kw) {
    var depth = 0;
    String? quote;

    bool isWordChar(String c) {
      final cu = c.codeUnitAt(0);
      final isAlphaNum =
          (cu >= 65 && cu <= 90) ||
          (cu >= 97 && cu <= 122) ||
          (cu >= 48 && cu <= 57) ||
          cu == 95;
      return isAlphaNum;
    }

    for (var i = 0; i + kw.length <= s.length; i++) {
      final ch = s[i];

      if (quote != null) {
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == "'" || ch == '"') {
        quote = ch;
        continue;
      }
      if (ch == "(") {
        depth++;
        continue;
      }
      if (ch == ")") {
        depth--;
        continue;
      }
      if (depth != 0) continue;

      if (s.substring(i, i + kw.length) == kw) {
        final before = i == 0 ? null : s[i - 1];
        final after = (i + kw.length) >= s.length ? null : s[i + kw.length];

        final beforeOk = before == null || !isWordChar(before);
        final afterOk = after == null || !isWordChar(after);

        if (beforeOk && afterOk) {
          return (i, i + kw.length);
        }
      }
    }

    return null;
  }
}

class TruthyCondition extends Condition {
  final Expression expr;
  TruthyCondition(this.expr);

  @override
  bool eval(RenderContext ctx) {
    final v = expr.eval(ctx);
    return v != null && v != false;
  }
}

class NotCondition extends Condition {
  final Condition inner;
  NotCondition(this.inner);

  @override
  bool eval(RenderContext ctx) => !inner.eval(ctx);
}

class AndCondition extends Condition {
  final List<Condition> parts;
  AndCondition(this.parts);

  @override
  bool eval(RenderContext ctx) {
    for (final p in parts) {
      if (!p.eval(ctx)) return false;
    }
    return true;
  }
}

class OrCondition extends Condition {
  final List<Condition> parts;
  OrCondition(this.parts);

  @override
  bool eval(RenderContext ctx) {
    for (final p in parts) {
      if (p.eval(ctx)) return true;
    }
    return false;
  }
}

class CompareCondition extends Condition {
  final Expression left;
  final CompareOp op;
  final Expression right;

  CompareCondition({required this.left, required this.op, required this.right});

  num? _toNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  @override
  bool eval(RenderContext ctx) {
    final a = left.eval(ctx);
    final b = right.eval(ctx);

    switch (op) {
      case CompareOp.eq:
        final an = _toNum(a);
        final bn = _toNum(b);
        if (an != null && bn != null) return an == bn;
        return a == b;

      case CompareOp.neq:
        final an = _toNum(a);
        final bn = _toNum(b);
        if (an != null && bn != null) return an != bn;
        return a != b;

      case CompareOp.gt:
      case CompareOp.gte:
      case CompareOp.lt:
      case CompareOp.lte:
        final an = _toNum(a);
        final bn = _toNum(b);

        if (an != null && bn != null) {
          if (op == CompareOp.gt) return an > bn;
          if (op == CompareOp.gte) return an >= bn;
          if (op == CompareOp.lt) return an < bn;
          return an <= bn;
        }

        final as = (a ?? "").toString();
        final bs = (b ?? "").toString();
        final c = as.compareTo(bs);
        if (op == CompareOp.gt) return c > 0;
        if (op == CompareOp.gte) return c >= 0;
        if (op == CompareOp.lt) return c < 0;
        return c <= 0;

      case CompareOp.contains:
        if (a is String) {
          return a.contains((b ?? "").toString());
        }
        if (a is List) {
          return a.contains(b);
        }
        if (a is Map) {
          return a.containsKey(b);
        }
        return false;
    }
  }
}
