import "../errors/liquid_error.dart";
import "../runtime/render_context.dart";
import "../source/source_location.dart";
import "expression.dart";

class FilterCall {
  final String name;
  final List<Expression> args;

  FilterCall({required this.name, required this.args});
}

class OutputExpression {
  final Expression base;
  final List<FilterCall> filters;

  OutputExpression({required this.base, required this.filters});

  Object? eval(RenderContext ctx, {SourceLocation? location}) {
    Object? v = base.eval(ctx);

    for (final f in filters) {
      final fn = ctx.filters.lookup(f.name);
      if (fn == null) {
        if (ctx.options.strictFilters) {
          throw LiquidRenderError(
            "Unknown filter: ${f.name}",
            location: location,
          );
        }
        continue;
      }
      final args = f.args.map((a) => a.eval(ctx)).toList(growable: false);
      v = fn(v, args);
    }

    return v;
  }

  static OutputExpression parse(String raw) {
    final parts = _splitByPipe(raw);
    if (parts.isEmpty) {
      throw LiquidParseError("Empty output expression");
    }

    final base = Expression.parse(parts.first);

    final filters = <FilterCall>[];
    for (var i = 1; i < parts.length; i++) {
      final p = parts[i].trim();
      if (p.isEmpty) continue;

      final colon = _indexOfTopLevelColon(p);
      String name;
      List<Expression> args = const [];

      if (colon == -1) {
        name = p.trim();
      } else {
        name = p.substring(0, colon).trim();
        final argStr = p.substring(colon + 1).trim();
        if (argStr.isNotEmpty) {
          final argParts = _splitArgs(argStr);
          args = argParts.map(Expression.parse).toList(growable: false);
        } else {
          args = const [];
        }
      }

      if (name.isEmpty) throw LiquidParseError("Invalid filter: $p");
      filters.add(FilterCall(name: name, args: args));
    }

    return OutputExpression(base: base, filters: filters);
  }

  static List<String> _splitByPipe(String s) {
    final out = <String>[];
    final buf = StringBuffer();

    String? quote;
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

      if (ch == "|") {
        out.add(buf.toString().trim());
        buf.clear();
        continue;
      }

      buf.write(ch);
    }

    final last = buf.toString().trim();
    if (last.isNotEmpty) out.add(last);
    return out;
  }

  static int _indexOfTopLevelColon(String s) {
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
      if (ch == ":") return i;
    }
    return -1;
  }

  static List<String> _splitArgs(String s) {
    final out = <String>[];
    final buf = StringBuffer();

    String? quote;
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

      if (ch == ",") {
        final part = buf.toString().trim();
        if (part.isNotEmpty) out.add(part);
        buf.clear();
        continue;
      }

      buf.write(ch);
    }

    final last = buf.toString().trim();
    if (last.isNotEmpty) out.add(last);
    return out;
  }
}
