import "../errors/liquid_error.dart";
import "../runtime/render_context.dart";
import "../runtime/value_resolver.dart";
import "var_path.dart";

sealed class Expression {
  Object? eval(RenderContext ctx);

  static Expression parse(String input) {
    final s = input.trim();
    final rangeParts = _tryParseRange(s);
    if (rangeParts != null) {
      final (aRaw, bRaw) = rangeParts;
      return RangeExpr(Expression.parse(aRaw), Expression.parse(bRaw));
    }

    if (s.isEmpty) throw LiquidParseError("Empty expression");

    if (s == "true") return BoolExpr(true);
    if (s == "false") return BoolExpr(false);
    if (s == "nil" || s == "null") return NilExpr();

    if ((s.startsWith('"') && s.endsWith('"')) ||
        (s.startsWith("'") && s.endsWith("'"))) {
      if (s.length < 2) throw LiquidParseError("Invalid string literal: $s");
      return StringExpr(_unescape(s.substring(1, s.length - 1)));
    }

    final n = num.tryParse(s);
    if (n != null) return NumberExpr(n);

    return VarExpr(VarPath.parse(s));
  }

  static String _unescape(String s) {
    return s.replaceAll(r"\'", "'").replaceAll(r'\"', '"');
  }

  static (String, String)? _tryParseRange(String s) {
    final t = s.trim();
    if (!(t.startsWith("(") && t.endsWith(")"))) return null;

    final inner = t.substring(1, t.length - 1).trim();
    if (inner.isEmpty) return null;

    String? quote;
    var depth = 0;

    for (var i = 0; i < inner.length - 1; i++) {
      final ch = inner[i];

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

      if (depth == 0 && inner[i] == "." && inner[i + 1] == ".") {
        final left = inner.substring(0, i).trim();
        final right = inner.substring(i + 2).trim();
        if (left.isEmpty || right.isEmpty) {
          throw LiquidParseError("Invalid range: $s");
        }
        return (left, right);
      }
    }

    return null;
  }
}

class RangeExpr extends Expression {
  final Expression startExpr;
  final Expression endExpr;

  RangeExpr(this.startExpr, this.endExpr);

  int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  @override
  Object? eval(RenderContext ctx) {
    final a = _toInt(startExpr.eval(ctx));
    final b = _toInt(endExpr.eval(ctx));

    if (a > b) return <int>[];

    final out = <int>[];
    for (var i = a; i <= b; i++) {
      out.add(i);
    }
    return out;
  }
}

class VarExpr extends Expression {
  final VarPath path;
  VarExpr(this.path);

  @override
  Object? eval(RenderContext ctx) => ValueResolver.resolve(ctx, path);
}

class StringExpr extends Expression {
  final String value;
  StringExpr(this.value);

  @override
  Object? eval(RenderContext ctx) => value;
}

class NumberExpr extends Expression {
  final num value;
  NumberExpr(this.value);

  @override
  Object? eval(RenderContext ctx) => value;
}

class BoolExpr extends Expression {
  final bool value;
  BoolExpr(this.value);

  @override
  Object? eval(RenderContext ctx) => value;
}

class NilExpr extends Expression {
  NilExpr();

  @override
  Object? eval(RenderContext ctx) => null;
}
