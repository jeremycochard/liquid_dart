import "dart:convert";

import "../ast/node.dart";
import "../errors/liquid_error.dart";
import "../expressions/expression.dart";
import "../filesystem/liquid_filesystem.dart";
import "../filters/filter_registry.dart";
import "../filters/where_exp.dart";
import "../lexer/lexer.dart";
import "../parser/parser.dart";
import "../runtime/control_flow.dart";
import "../runtime/render_context.dart";
import "../runtime/render_limits.dart";
import "../source/source_location.dart";
import "../utils/liquid_date.dart";
import "liquid_options.dart";

class LiquidEngine {
  final LiquidOptions options;
  final FilterRegistry filters = FilterRegistry();
  final LiquidFileSystem fileSystem;

  final Map<String, LiquidTemplate> _templateCache = {};

  LiquidEngine({LiquidOptions? options, LiquidFileSystem? fileSystem})
    : options = options ?? const LiquidOptions(),
      fileSystem = fileSystem ?? NoopFileSystem() {
    _registerBuiltinFilters();
  }

  void registerFilter(String name, LiquidFilter fn) {
    filters.register(name, fn);
  }

  void _registerBuiltinFilters() {
    String toStr(Object? v) => (v ?? "").toString();

    String applyImgSizeSuffix(String url, String size) {
      final s = size.trim();
      if (s.isEmpty || s == "master") return url;

      final q = url.indexOf("?");
      final base = q >= 0 ? url.substring(0, q) : url;
      final query = q >= 0 ? url.substring(q) : "";

      final slash = base.lastIndexOf("/");
      final dot = base.lastIndexOf(".");

      if (dot <= slash || dot < 0) {
        return "${base}_$s$query";
      }

      final name = base.substring(0, dot);
      final ext = base.substring(dot);
      return "${name}_$s$ext$query";
    }

    String assetUrl(String key) {
      final k = key.trim();
      if (k.isEmpty) return "";
      final r = options.assetUrlResolver;
      return r != null ? r(k) : k;
    }

    String fileUrl(String key) {
      final k = key.trim();
      if (k.isEmpty) return "";
      final r = options.fileUrlResolver;
      return r != null ? r(k) : k;
    }

    String imageUrl(String key, String size) {
      final k = key.trim();
      if (k.isEmpty) return "";
      final r = options.imageUrlResolver;
      if (r != null) return r(k, size);
      return applyImgSizeSuffix(k, size);
    }

    int sizeOf(Object? v) {
      if (v == null) return 0;
      if (v is String) return v.length;
      if (v is List) return v.length;
      if (v is Map) return v.length;
      if (v is Iterable) return v.length;
      return 0;
    }

    Object? getProp(Object? item, String path) {
      var cur = item;
      final parts = path.split(".");
      for (final p in parts) {
        final key = p.trim();
        if (key.isEmpty) return null;
        if (cur == null) return null;

        if (key == "size") {
          if (cur is String) {
            cur = cur.length;
            continue;
          }
          if (cur is List) {
            cur = cur.length;
            continue;
          }
          if (cur is Map) {
            cur = cur.containsKey("size") ? cur["size"] : cur.length;
            continue;
          }
        }

        if (cur is Map) {
          cur = cur[key];
          continue;
        }
        return null;
      }
      return cur;
    }

    num? tryNum(Object? v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim());
      return num.tryParse((v ?? "").toString().trim());
    }

    int cmpKeys(Object? a, Object? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;

      final an = tryNum(a);
      final bn = tryNum(b);
      if (an != null && bn != null) return an.compareTo(bn);

      final as = a.toString();
      final bs = b.toString();
      return as.compareTo(bs);
    }

    bool eqLoose(Object? a, Object? b) {
      final an = tryNum(a);
      final bn = tryNum(b);
      if (an != null && bn != null) return an == bn;
      return a == b;
    }

    bool truthy(Object? v) => v != null && v != false;

    num toNum(Object? v) {
      if (v == null) return 0;
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim()) ?? 0;
      return num.tryParse(v.toString().trim()) ?? 0;
    }

    int toInt(Object? v) {
      final n = toNum(v);
      if (n is int) return n;
      return n.toInt();
    }

    bool isIntNum(num x) {
      if (x is int) return true;
      if (x is double) return x == x.truncateToDouble();
      return false;
    }

    String escapeHtml(String s) {
      return s
          .replaceAll("&", "&amp;")
          .replaceAll("<", "&lt;")
          .replaceAll(">", "&gt;")
          .replaceAll('"', "&quot;")
          .replaceAll("'", "&#39;");
    }

    String stripHtml(String s) {
      return s.replaceAll(RegExp(r"<[^>]*>"), "");
    }

    String handleize(String s) {
      var t = s.toLowerCase();
      t = t.replaceAll(RegExp(r"[^\p{L}\p{N}\s-]+", unicode: true), "");
      t = t.replaceAll(RegExp(r"[\s_-]+"), "-");
      t = t.replaceAll(RegExp(r"^-+"), "").replaceAll(RegExp(r"-+$"), "");
      return t;
    }

    String truncateWords(String s, int words, String end) {
      if (words <= 0) return "";
      final parts = s.trim().split(RegExp(r"\s+"));
      if (parts.length <= words) return s.trim();
      return parts.take(words).join(" ") + end;
    }

    String formatMoneyCents(int cents, String fmt) {
      String amount2() {
        final v = (cents / 100.0);
        return v.toStringAsFixed(2);
      }

      String amount0() {
        final v = (cents / 100.0).round();
        return v.toString();
      }

      String amountComma() {
        final v = (cents / 100.0);
        final fixed = v.toStringAsFixed(2); // 1234.56
        final parts = fixed.split(".");
        final intPart = parts[0];
        final frac = parts[1];

        final buf = StringBuffer();
        for (var i = 0; i < intPart.length; i++) {
          final pos = intPart.length - i;
          buf.write(intPart[i]);
          if (pos > 1 && pos % 3 == 1) {
            buf.write(".");
          }
        }
        return "${buf.toString()},$frac";
      }

      var out = fmt;
      out = out.replaceAll("{{amount_with_comma_separator}}", amountComma());
      out = out.replaceAll("{{amount_no_decimals}}", amount0());
      out = out.replaceAll("{{amount}}", amount2());
      return out;
    }

    int cmpNatural(Object? a, Object? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;

      final an = tryNum(a);
      final bn = tryNum(b);
      if (an != null && bn != null) return an.compareTo(bn);

      final as = a.toString().toLowerCase();
      final bs = b.toString().toLowerCase();
      return as.compareTo(bs);
    }

    int moneyToCents(Object? v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return (v * 100).round();

      final s = v.toString().trim();
      if (s.isEmpty) return 0;

      final n = num.tryParse(s);
      if (n != null) {
        final isLikelyCents = RegExp(r"^\d+$").hasMatch(s);
        if (isLikelyCents) return n.toInt();
        return (n * 100).round();
      }

      return 0;
    }

    registerFilter("sort_natural", (input, args) {
      if (input is! List) return input;

      String? prop;
      if (args.isNotEmpty &&
          args[0] != null &&
          args[0].toString().trim().isNotEmpty) {
        prop = args[0].toString();
      }

      final indexed = <({int idx, Object? key, Object? value})>[];
      for (var i = 0; i < input.length; i++) {
        final v = input[i];
        final k = prop == null ? v : getProp(v, prop);
        indexed.add((idx: i, key: k, value: v));
      }

      indexed.sort((a, b) {
        final c = cmpNatural(a.key, b.key);
        if (c != 0) return c;
        return a.idx.compareTo(b.idx);
      });

      return indexed.map((e) => e.value).toList(growable: false);
    });

    registerFilter("dig", (input, args) {
      var cur = input;

      for (final a in args) {
        if (cur == null) return null;

        if (cur is List) {
          final idx = toInt(a);
          if (idx < 0 || idx >= cur.length) return null;
          cur = cur[idx];
          continue;
        }

        if (cur is Map) {
          final key = (a ?? "").toString();
          cur = cur[key];
          continue;
        }

        return null;
      }

      return cur;
    });

    registerFilter("link_to", (input, args) {
      final text = escapeHtml(toStr(input));
      final href = args.isNotEmpty ? toStr(args[0]) : "";
      final title = args.length > 1 ? toStr(args[1]) : "";

      final safeHref = escapeHtml(href);
      final safeTitle = escapeHtml(title);

      final titleAttr = safeTitle.isEmpty ? "" : ' title="$safeTitle"';
      return '<a href="$safeHref"$titleAttr>$text</a>';
    });

    registerFilter("where_exp", (input, args) {
      if (input is! List) return <Object?>[];

      final varName = args.isNotEmpty ? toStr(args[0]) : "";
      final expr = args.length > 1 ? toStr(args[1]) : "";

      if (varName.trim().isEmpty || expr.trim().isEmpty) return <Object?>[];

      return WhereExp.filter(input, varName, expr);
    });

    registerFilter("reject", (input, args) {
      if (input is! List) return <Object?>[];

      final prop = args.isNotEmpty ? toStr(args[0]) : "";
      if (prop.trim().isEmpty) return <Object?>[];

      final hasValue = args.length > 1;
      final wanted = hasValue ? args[1] : null;

      final out = <Object?>[];
      for (final e in input) {
        final pv = getProp(e, prop);

        if (!hasValue) {
          if (!truthy(pv)) out.add(e);
        } else {
          if (!eqLoose(pv, wanted)) out.add(e);
        }
      }
      return out;
    });

    registerFilter("reject_exp", (input, args) {
      if (input is! List) return <Object?>[];

      final varName = args.isNotEmpty ? toStr(args[0]) : "";
      final expr = args.length > 1 ? toStr(args[1]) : "";

      if (varName.trim().isEmpty || expr.trim().isEmpty) return <Object?>[];

      final selected = WhereExp.filter(input, varName, expr);
      final selectedSet = selected.toSet();

      final out = <Object?>[];
      for (final e in input) {
        if (!selectedSet.contains(e)) out.add(e);
      }
      return out;
    });

    registerFilter("group_by", (input, args) {
      if (input is! List) return <Object?>[];

      final prop = args.isNotEmpty ? toStr(args[0]) : "";
      if (prop.trim().isEmpty) return <Object?>[];

      final order = <String>[];
      final map = <String, List<Object?>>{};

      for (final e in input) {
        final keyVal = getProp(e, prop);
        final key = (keyVal ?? "").toString();

        if (!map.containsKey(key)) {
          map[key] = <Object?>[];
          order.add(key);
        }
        map[key]!.add(e);
      }

      return order
          .map((k) => <String, Object?>{"name": k, "items": map[k]!})
          .toList(growable: false);
    });

    registerFilter("concat", (input, args) {
      final a = input is List
          ? input
          : (input == null ? <Object?>[] : <Object?>[input]);
      final bRaw = args.isNotEmpty ? args[0] : null;
      final b = bRaw is List
          ? bRaw
          : (bRaw == null ? <Object?>[] : <Object?>[bRaw]);
      return <Object?>[...a.cast<Object?>(), ...b.cast<Object?>()];
    });

    registerFilter("asset_url", (input, args) {
      return assetUrl(toStr(input));
    });

    registerFilter("file_url", (input, args) {
      return fileUrl(toStr(input));
    });

    registerFilter("img_url", (input, args) {
      final size = args.isNotEmpty ? toStr(args[0]) : "master";
      return imageUrl(toStr(input), size);
    });

    registerFilter("shopify_asset_url", (input, args) {
      return assetUrl(toStr(input));
    });

    registerFilter("handleize", (input, args) => handleize(toStr(input)));

    registerFilter("truncatewords", (input, args) {
      final s = toStr(input);
      final n = args.isNotEmpty ? toInt(args[0]) : 15;
      final end = args.length > 1 ? toStr(args[1]) : "...";
      return truncateWords(s, n, end);
    });

    registerFilter("pluralize", (input, args) {
      final n = toInt(input);
      final singular = args.isNotEmpty ? toStr(args[0]) : "";
      final plural = args.length > 1 ? toStr(args[1]) : "";
      return n == 1 ? singular : plural;
    });

    registerFilter(
      "url_escape",
      (input, args) => Uri.encodeComponent(toStr(input)),
    );

    registerFilter("money", (input, args) {
      final cents = moneyToCents(input);
      final fmt =
          args.isNotEmpty && args[0] != null && args[0].toString().isNotEmpty
          ? args[0].toString()
          : options.moneyFormat;
      return formatMoneyCents(cents, fmt);
    });

    registerFilter("date", (input, args) {
      final instant = LiquidDate.parseToInstant(input);
      if (instant == null) return "";

      String fmt;
      Object? tzArg;

      if (args.isEmpty || args[0] == null || args[0].toString().isEmpty) {
        fmt = options.dateFormat;
      } else {
        fmt = args[0].toString();
      }

      if (args.length > 1) {
        tzArg = args[1];
      }

      final tz = LiquidDate.resolveTimeZone(
        instantUtc: instant,
        options: options,
        tzArg: tzArg,
      );

      return LiquidDate.format(instantUtc: instant, format: fmt, tz: tz);
    });

    registerFilter("json", (input, args) {
      return jsonEncode(input);
    });

    registerFilter("escape", (input, args) {
      return escapeHtml(toStr(input));
    });

    registerFilter("url_encode", (input, args) {
      return Uri.encodeComponent(toStr(input));
    });

    registerFilter("truncate", (input, args) {
      final s = toStr(input);
      final len = args.isNotEmpty ? toInt(args[0]) : 50;
      final end = args.length > 1 ? toStr(args[1]) : "...";

      if (len <= 0) return "";
      if (s.length <= len) return s;

      if (len <= end.length) {
        return end.substring(0, len);
      }

      final cut = len - end.length;
      return s.substring(0, cut) + end;
    });

    registerFilter("newline_to_br", (input, args) {
      final s = toStr(input);
      return s
          .replaceAll("\r\n", "\n")
          .replaceAll("\r", "\n")
          .replaceAll("\n", "<br />\n");
    });

    registerFilter("strip_html", (input, args) {
      return stripHtml(toStr(input));
    });

    registerFilter("size", (input, args) => sizeOf(input));

    registerFilter("first", (input, args) {
      if (input is List) return input.isEmpty ? null : input.first;
      final s = (input ?? "").toString();
      if (s.isEmpty) return null;
      return s[0];
    });

    registerFilter("last", (input, args) {
      if (input is List) return input.isEmpty ? null : input.last;
      final s = (input ?? "").toString();
      if (s.isEmpty) return null;
      return s[s.length - 1];
    });

    registerFilter("reverse", (input, args) {
      if (input is List) return input.reversed.toList(growable: false);
      return input;
    });

    registerFilter("compact", (input, args) {
      if (input is List) {
        return input.where((e) => e != null).toList(growable: false);
      }
      return input;
    });

    registerFilter("uniq", (input, args) {
      if (input is! List) return input;

      String? prop;
      if (args.isNotEmpty &&
          args[0] != null &&
          args[0].toString().trim().isNotEmpty) {
        prop = args[0].toString();
      }

      final seen = <String, bool>{};
      final out = <Object?>[];

      for (final e in input) {
        final keyVal = prop == null ? e : getProp(e, prop);
        final k = (keyVal == null) ? "__nil__" : keyVal.toString();
        if (seen.containsKey(k)) continue;
        seen[k] = true;
        out.add(e);
      }

      return out;
    });

    registerFilter("map", (input, args) {
      if (input is! List) return <Object?>[];
      final prop = args.isNotEmpty ? (args[0] ?? "").toString() : "";
      if (prop.trim().isEmpty) return <Object?>[];
      return input.map((e) => getProp(e, prop)).toList(growable: false);
    });

    registerFilter("where", (input, args) {
      if (input is! List) return <Object?>[];

      final prop = args.isNotEmpty ? (args[0] ?? "").toString() : "";
      if (prop.trim().isEmpty) return <Object?>[];

      final hasValue = args.length > 1;
      final wanted = hasValue ? args[1] : null;

      final out = <Object?>[];
      for (final e in input) {
        final pv = getProp(e, prop);
        if (!hasValue) {
          if (truthy(pv)) out.add(e);
        } else {
          if (eqLoose(pv, wanted)) out.add(e);
        }
      }
      return out;
    });

    registerFilter("sort", (input, args) {
      if (input is! List) return input;

      String? prop;
      if (args.isNotEmpty &&
          args[0] != null &&
          args[0].toString().trim().isNotEmpty) {
        prop = args[0].toString();
      }

      final indexed = <({int idx, Object? key, Object? value})>[];
      for (var i = 0; i < input.length; i++) {
        final v = input[i];
        final k = prop == null ? v : getProp(v, prop);
        indexed.add((idx: i, key: k, value: v));
      }

      indexed.sort((a, b) {
        final c = cmpKeys(a.key, b.key);
        if (c != 0) return c;
        return a.idx.compareTo(b.idx);
      });

      return indexed.map((e) => e.value).toList(growable: false);
    });

    registerFilter("upcase", (input, args) {
      final s = (input ?? "").toString();
      return s.toUpperCase();
    });

    registerFilter("downcase", (input, args) {
      final s = (input ?? "").toString();
      return s.toLowerCase();
    });

    registerFilter("capitalize", (input, args) {
      final s = (input ?? "").toString();
      if (s.isEmpty) return s;
      return s[0].toUpperCase() + s.substring(1);
    });

    registerFilter("append", (input, args) {
      final s = (input ?? "").toString();
      final tail = args.isNotEmpty ? (args[0] ?? "").toString() : "";
      return s + tail;
    });

    registerFilter("prepend", (input, args) {
      final s = (input ?? "").toString();
      final head = args.isNotEmpty ? (args[0] ?? "").toString() : "";
      return head + s;
    });

    registerFilter("default", (input, args) {
      bool blank(Object? v) {
        if (v == null) return true;
        if (v is String) return v.isEmpty;
        if (v is List) return v.isEmpty;
        if (v is Map) return v.isEmpty;
        return false;
      }

      if (!blank(input)) return input;
      return args.isNotEmpty ? args[0] : input;
    });

    registerFilter("plus", (input, args) {
      return toNum(input) + toNum(args.isNotEmpty ? args[0] : 0);
    });

    registerFilter("minus", (input, args) {
      return toNum(input) - toNum(args.isNotEmpty ? args[0] : 0);
    });

    registerFilter("times", (input, args) {
      return toNum(input) * toNum(args.isNotEmpty ? args[0] : 0);
    });

    registerFilter("divided_by", (input, args) {
      final a = toNum(input);
      final b = toNum(args.isNotEmpty ? args[0] : 0);
      if (b == 0) return 0;

      final aIsInt = isIntNum(a);
      final bIsInt = isIntNum(b);

      if (aIsInt && bIsInt) {
        return toInt(a) ~/ toInt(b);
      }
      return a / b;
    });

    registerFilter("modulo", (input, args) {
      final a = toInt(input);
      final b = toInt(args.isNotEmpty ? args[0] : 0);
      if (b == 0) return 0;
      return a % b;
    });

    registerFilter("abs", (input, args) {
      final a = toNum(input);
      return a.abs();
    });

    registerFilter("floor", (input, args) {
      final a = toNum(input);
      return a.floor();
    });

    registerFilter("ceil", (input, args) {
      final a = toNum(input);
      return a.ceil();
    });

    registerFilter("round", (input, args) {
      final a = toNum(input).toDouble();
      final precision = args.isNotEmpty ? toInt(args[0]) : 0;
      if (precision <= 0) return a.round();

      double pow10(int n) {
        var r = 1.0;
        for (var i = 0; i < n; i++) {
          r *= 10.0;
        }
        return r;
      }

      final m = pow10(precision);
      return (a * m).round() / m;
    });
    registerFilter("strip", (input, args) => toStr(input).trim());

    registerFilter(
      "lstrip",
      (input, args) => toStr(input).replaceFirst(RegExp(r"^\s+"), ""),
    );

    registerFilter(
      "rstrip",
      (input, args) => toStr(input).replaceFirst(RegExp(r"\s+$"), ""),
    );

    registerFilter(
      "strip_newlines",
      (input, args) => toStr(input).replaceAll("\n", "").replaceAll("\r", ""),
    );

    registerFilter("replace", (input, args) {
      final s = toStr(input);
      final from = args.isNotEmpty ? toStr(args[0]) : "";
      final to = args.length > 1 ? toStr(args[1]) : "";
      return s.replaceAll(from, to);
    });

    registerFilter("replace_first", (input, args) {
      final s = toStr(input);
      final from = args.isNotEmpty ? toStr(args[0]) : "";
      final to = args.length > 1 ? toStr(args[1]) : "";
      return s.replaceFirst(from, to);
    });

    registerFilter("remove", (input, args) {
      final s = toStr(input);
      final what = args.isNotEmpty ? toStr(args[0]) : "";
      return s.replaceAll(what, "");
    });

    registerFilter("remove_first", (input, args) {
      final s = toStr(input);
      final what = args.isNotEmpty ? toStr(args[0]) : "";
      return s.replaceFirst(what, "");
    });

    registerFilter("split", (input, args) {
      final s = toStr(input);
      final sep = args.isNotEmpty ? toStr(args[0]) : " ";
      return s.split(sep);
    });

    registerFilter("join", (input, args) {
      final sep = args.isNotEmpty ? toStr(args[0]) : " ";
      if (input is List) {
        return input.map((e) => (e ?? "").toString()).join(sep);
      }
      return toStr(input);
    });

    registerFilter("slice", (input, args) {
      final s = toStr(input);
      if (args.isEmpty) return "";
      final start = toInt(args[0]);
      final len = args.length > 1 ? toInt(args[1]) : 1;

      var a = start;
      if (a < 0) a = s.length + a;
      if (a < 0) a = 0;
      if (a > s.length) return "";

      var b = a + len;
      if (b < a) return "";
      if (b > s.length) b = s.length;
      return s.substring(a, b);
    });
  }

  LiquidTemplate parse(String source) {
    try {
      final tokens = Lexer(source).tokenize();
      final nodes = Parser().parse(tokens);

      Expression? layoutExpr;
      SourceLocation? layoutLoc;
      final filtered = <Node>[];

      for (final n in nodes) {
        if (n is LayoutNode && layoutExpr == null) {
          layoutExpr = n.nameExpr;
          layoutLoc = n.location;
          continue;
        }
        filtered.add(n);
      }

      return LiquidTemplate._(
        nodes: filtered,
        source: source,
        layoutNameExpr: layoutExpr,
        layoutLocation: layoutLoc,
      );
    } on LiquidError catch (e) {
      final loc = e.location;
      if (loc == null) rethrow;
      final enrichedLoc = LiquidError.attachLine(loc, source);
      if (e is LiquidParseError) {
        throw LiquidParseError(e.message, location: enrichedLoc);
      }
      throw LiquidRenderError(e.message, location: enrichedLoc);
    } catch (e) {
      throw LiquidParseError(e.toString());
    }
  }

  Future<String> parseAndRender(
    String source,
    Map<String, Object?> data,
  ) async {
    final tpl = parse(source);
    return _renderTemplate(tpl, data);
  }

  Future<String> renderFile(String name, Map<String, Object?> data) async {
    final tpl = await _loadTemplateByName(name);
    return _renderTemplate(tpl, data);
  }

  void _collectTopLevelBlocks(RenderContext ctx, List<Node> nodes) {
    for (final n in nodes) {
      if (n is BlockNode) {
        ctx.blocks.define(n.name, n.body);
      }
    }
  }

  Future<String> _renderTemplate(
    LiquidTemplate tpl,
    Map<String, Object?> data,
  ) async {
    final out = StringBuffer();

    final ctx = RenderContext(
      globals: data,
      options: options,
      filters: filters,
      renderPartial: _renderPartial,
      limits: RenderLimits(
        maxDepth: options.maxRenderDepth,
        maxSteps: options.maxRenderSteps,
        maxOutputSize: options.maxOutputSize,
      ),
    );

    try {
      if (tpl.layoutNameExpr == null) {
        try {
          await tpl.renderTo(out, ctx);
        } on LiquidError catch (e) {
          final loc = e.location;
          if (loc == null) rethrow;
          throw LiquidRenderError(
            e.message,
            location: LiquidError.attachLine(loc, tpl.source),
          );
        }

        return out.toString();
      }

      _collectTopLevelBlocks(ctx, tpl.nodes);

      final layoutNameVal = tpl.layoutNameExpr!.eval(ctx);
      final loc = tpl.layoutLocation;
      if (layoutNameVal == null) {
        throw LiquidRenderError("Invalid layout name", location: loc);
      }
      final layoutName = layoutNameVal.toString();

      LiquidTemplate layoutTpl;
      try {
        layoutTpl = await _loadTemplateByName(layoutName);
      } on LiquidError catch (e) {
        if (e.location != null) rethrow;
        throw LiquidRenderError(e.message, location: tpl.layoutLocation);
      }

      try {
        ctx.limits.enter("layout:$layoutName");
        try {
          await layoutTpl.renderTo(out, ctx);
        } finally {
          ctx.limits.exit();
        }
      } on LiquidError catch (e) {
        final loc = e.location;
        if (loc == null) rethrow;
        throw LiquidRenderError(
          e.message,
          location: LiquidError.attachLine(loc, layoutTpl.source),
        );
      }

      return out.toString();
    } on BreakSignal {
      throw LiquidRenderError("break outside of for loop");
    } on ContinueSignal {
      throw LiquidRenderError("continue outside of for loop");
    }
  }

  Future<void> _renderPartial(
    String name,
    StringBuffer out,
    RenderContext ctx,
  ) async {
    ctx.limits.enter(name);
    try {
      final tpl = await _loadTemplateByName(name);
      await tpl.renderTo(out, ctx);
    } finally {
      ctx.limits.exit();
    }
  }

  Future<LiquidTemplate> _loadTemplateByName(String name) async {
    if (options.cacheTemplates) {
      final cached = _templateCache[name];
      if (cached != null) return cached;
    }

    final source = await fileSystem.readTemplate(name);
    final tpl = parse(source);

    if (options.cacheTemplates) {
      _templateCache[name] = tpl;
    }
    return tpl;
  }
}

class LiquidTemplate {
  final List<Node> nodes;
  final String source;
  final Expression? layoutNameExpr;
  final SourceLocation? layoutLocation;

  LiquidTemplate._({
    required this.nodes,
    required this.source,
    required this.layoutNameExpr,
    this.layoutLocation,
  });

  Future<void> renderTo(StringBuffer out, RenderContext ctx) async {
    for (final n in nodes) {
      ctx.limits.tick();
      await n.renderTo(out, ctx);
      ctx.limits.checkOutput(out);
    }
  }
}
