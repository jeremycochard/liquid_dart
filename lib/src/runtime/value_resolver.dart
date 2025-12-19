import "../../liquid_dart.dart";
import "../expressions/var_path.dart";
import "render_context.dart";

class ValueResolver {
  static Object? resolve(RenderContext ctx, VarPath path) {
    Object? current = ctx.lookup(path.root);

    for (final seg in path.segments) {
      if (current == null) return null;

      if (seg is KeySegment) {
        if (seg.key == "size") {
          if (current is String) return current.length;
          if (current is List) return current.length;
          if (current is Map) {
            if (current.containsKey("size")) return current["size"];
            return current.length;
          }
        }

        if (current is Map) {
          current = current[seg.key];
          continue;
        }

        if (ctx.options.allowDrops && current is LiquidDrop) {
          final v = current.get(seg.key);
          if (v is LiquidCallable0) {
            current = v();
          } else {
            current = v;
          }
          continue;
        }

        return null;
      }

      if (seg is IndexSegment) {
        if (current is List) {
          final idx = seg.index;
          if (idx < 0 || idx >= current.length) return null;
          current = current[idx];
          continue;
        }
        return null;
      }
    }

    return current;
  }
}
