import "../conditions/condition.dart";
import "../errors/liquid_error.dart";
import "../expressions/expression.dart";
import "../expressions/output_expression.dart";
import "../runtime/control_flow.dart";
import "../runtime/render_context.dart";
import "../source/source_location.dart";

abstract class Node {
  Future<void> renderTo(StringBuffer out, RenderContext ctx);
}

class TextNode extends Node {
  final String text;
  TextNode(this.text);

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    out.write(text);
  }
}

class OutputNode extends Node {
  final String raw;
  final OutputExpression expr;
  final SourceLocation location;

  OutputNode({required this.raw, required this.expr, required this.location});

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    final baseIsVar = expr.base is VarExpr;

    final v = expr.eval(ctx, location: location);

    if (v == null) {
      if (ctx.options.strictVariables && baseIsVar) {
        throw LiquidRenderError("Undefined variable: $raw", location: location);
      }
      return;
    }

    if (v is bool) {
      out.write(v ? "true" : "false");
      return;
    }

    if (v is List) {
      for (final e in v) {
        if (e == null) continue;
        out.write(e.toString());
      }
      return;
    }

    out.write(v.toString());
  }
}

class AssignNode extends Node {
  final String name;
  final OutputExpression valueExpr;
  final SourceLocation location;

  AssignNode({
    required this.name,
    required this.valueExpr,
    required this.location,
  });

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    final v = valueExpr.eval(ctx, location: location);
    ctx.set(name, v);
  }
}

class IfBranch {
  final Condition? condition; // null = else
  final List<Node> body;

  IfBranch({required this.condition, required this.body});
}

class IfNode extends Node {
  final List<IfBranch> branches;

  IfNode({required this.branches});

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    for (final b in branches) {
      final ok = b.condition == null ? true : b.condition!.eval(ctx);
      if (!ok) continue;

      for (final n in b.body) {
        await n.renderTo(out, ctx);
      }
      return;
    }
  }
}

class BreakNode extends Node {
  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    throw BreakSignal();
  }
}

class ContinueNode extends Node {
  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    throw ContinueSignal();
  }
}

class ForNode extends Node {
  final String itemName;
  final OutputExpression collectionExpr;
  final Expression? limitExpr;
  final Expression? offsetExpr;
  final bool reversed;
  final List<Node> body;
  final List<Node>? elseBody;

  ForNode({
    required this.itemName,
    required this.collectionExpr,
    required this.limitExpr,
    required this.offsetExpr,
    required this.reversed,
    required this.body,
    required this.elseBody,
  });

  int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  List<Object?> _toList(Object? v) {
    if (v == null) return const [];
    if (v is List) return v.cast<Object?>();
    if (v is Iterable) {
      return v.map((e) => e as Object?).toList(growable: false);
    }
    return const [];
  }

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    var list = _toList(collectionExpr.eval(ctx));

    if (offsetExpr != null) {
      final off = _toInt(offsetExpr!.eval(ctx));
      if (off > 0 && off < list.length) {
        list = list.sublist(off);
      } else if (off >= list.length) {
        list = const [];
      }
    }

    if (limitExpr != null) {
      final lim = _toInt(limitExpr!.eval(ctx));
      if (lim >= 0 && lim < list.length) {
        list = list.sublist(0, lim);
      }
    }

    if (reversed && list.isNotEmpty) {
      list = list.reversed.toList(growable: false);
    }

    if (list.isEmpty) {
      if (elseBody != null) {
        for (final n in elseBody!) {
          await n.renderTo(out, ctx);
        }
      }
      return;
    }

    ctx.pushScope();
    try {
      final parentForLoop = ctx.lookup("forloop");
      final length = list.length;

      for (var i = 0; i < length; i++) {
        ctx.limits.tick();

        ctx.setLocal(itemName, list[i]);
        ctx.setLocal("forloop", <String, Object?>{
          "index": i + 1,
          "index0": i,
          "rindex": length - i,
          "rindex0": length - i - 1,
          "first": i == 0,
          "last": i == length - 1,
          "length": length,
          "parentloop": parentForLoop,
        });

        try {
          for (final n in body) {
            await n.renderTo(out, ctx);
          }
          ctx.limits.checkOutput(out);
        } on ContinueSignal {
          continue;
        } on BreakSignal {
          break;
        }
      }
    } finally {
      ctx.popScope();
    }
  }
}

class CaseBranch {
  final List<Expression> values;
  final List<Node> body;

  CaseBranch({required this.values, required this.body});
}

class CaseNode extends Node {
  final Expression valueExpr;
  final List<CaseBranch> branches;
  final List<Node>? elseBody;

  CaseNode({
    required this.valueExpr,
    required this.branches,
    required this.elseBody,
  });

  num? _toNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return null;
  }

  bool _eq(Object? a, Object? b) {
    final an = _toNum(a);
    final bn = _toNum(b);
    if (an != null && bn != null) return an == bn;
    return a == b;
  }

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    final v = valueExpr.eval(ctx);

    for (final br in branches) {
      for (final w in br.values) {
        final wv = w.eval(ctx);
        if (_eq(v, wv)) {
          for (final n in br.body) {
            await n.renderTo(out, ctx);
          }
          return;
        }
      }
    }

    if (elseBody != null) {
      for (final n in elseBody!) {
        await n.renderTo(out, ctx);
      }
    }
  }
}

class CaptureNode extends Node {
  final String name;
  final List<Node> body;

  CaptureNode({required this.name, required this.body});

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    final buf = StringBuffer();
    for (final n in body) {
      await n.renderTo(buf, ctx);
    }
    ctx.set(name, buf.toString());
  }
}

class IncrementNode extends Node {
  final String name;
  IncrementNode(this.name);

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    out.write(ctx.increment(name).toString());
  }
}

class DecrementNode extends Node {
  final String name;
  DecrementNode(this.name);

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    out.write(ctx.decrement(name).toString());
  }
}

class PartialNode extends Node {
  final bool isolate;
  final Expression nameExpr;
  final Map<String, Expression> namedArgs;
  final SourceLocation location;

  PartialNode({
    required this.isolate,
    required this.nameExpr,
    required this.namedArgs,
    required this.location,
  });

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    final nameVal = nameExpr.eval(ctx);
    if (nameVal == null) {
      throw LiquidRenderError("Invalid template name", location: location);
    }
    final name = nameVal.toString();

    final evaluatedArgs = <String, Object?>{};
    for (final e in namedArgs.entries) {
      evaluatedArgs[e.key] = e.value.eval(ctx);
    }

    if (!isolate) {
      ctx.pushScope();
      try {
        for (final kv in evaluatedArgs.entries) {
          ctx.setLocal(kv.key, kv.value);
        }
        try {
          await ctx.renderPartial(name, out, ctx);
        } on LiquidError catch (e) {
          if (e.location != null) rethrow;
          throw LiquidRenderError(e.message, location: location);
        }
      } finally {
        ctx.popScope();
      }
      return;
    }

    final child = ctx.forkForRender();
    for (final kv in evaluatedArgs.entries) {
      child.setLocal(kv.key, kv.value);
    }
    try {
      await child.renderPartial(name, out, child);
    } on LiquidError catch (e) {
      if (e.location != null) rethrow;
      throw LiquidRenderError(e.message, location: location);
    }
  }
}

class LayoutNode extends Node {
  final Expression nameExpr;
  final SourceLocation location;

  LayoutNode({required this.nameExpr, required this.location});

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {}
}

class BlockNode extends Node {
  final String name;
  final List<Node> body;

  BlockNode({required this.name, required this.body});

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    final overrideBody = ctx.blocks.lookup(name);
    final toRender = overrideBody ?? body;
    for (final n in toRender) {
      await n.renderTo(out, ctx);
    }
  }
}

class CycleNode extends Node {
  final String group;
  final List<Expression> values;

  CycleNode({required this.group, required this.values});

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    if (values.isEmpty) return;
    final idx = ctx.nextCycleIndex(group, values.length);
    final v = values[idx].eval(ctx);
    if (v == null) return;
    out.write(v.toString());
  }
}

class TableRowNode extends Node {
  final String itemName;
  final OutputExpression collectionExpr;
  final Expression? colsExpr;
  final Expression? limitExpr;
  final Expression? offsetExpr;
  final List<Node> body;

  TableRowNode({
    required this.itemName,
    required this.collectionExpr,
    required this.colsExpr,
    required this.limitExpr,
    required this.offsetExpr,
    required this.body,
  });

  int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }

  List<Object?> _toList(Object? v) {
    if (v == null) return const [];
    if (v is List) return v.cast<Object?>();
    if (v is Iterable) {
      return v.map((e) => e as Object?).toList(growable: false);
    }
    return const [];
  }

  @override
  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    var list = _toList(collectionExpr.eval(ctx));

    if (offsetExpr != null) {
      final off = _toInt(offsetExpr!.eval(ctx));
      if (off > 0 && off < list.length) {
        list = list.sublist(off);
      } else if (off >= list.length) {
        list = const [];
      }
    }

    if (limitExpr != null) {
      final lim = _toInt(limitExpr!.eval(ctx));
      if (lim >= 0 && lim < list.length) {
        list = list.sublist(0, lim);
      }
    }

    final colsRaw = colsExpr != null ? _toInt(colsExpr!.eval(ctx)) : 1;
    final cols = colsRaw <= 0 ? 1 : colsRaw;

    if (list.isEmpty) return;

    ctx.pushScope();
    try {
      final length = list.length;
      var row = 1;
      var col = 0;

      for (var i = 0; i < length; i++) {
        ctx.limits.tick();

        if (col == 0) {
          out.write('<tr class="row$row">');
        }

        col++;
        out.write('<td class="col$col">');

        ctx.setLocal(itemName, list[i]);
        ctx.setLocal("tablerowloop", <String, Object?>{
          "index": i + 1,
          "index0": i,
          "row": row,
          "col": col,
          "length": length,
        });

        for (final n in body) {
          await n.renderTo(out, ctx);
        }

        ctx.limits.checkOutput(out);

        out.write("</td>");

        if (col == cols || i == length - 1) {
          out.write("</tr>");
          row++;
          col = 0;
        }
      }
    } finally {
      ctx.popScope();
    }
  }
}
