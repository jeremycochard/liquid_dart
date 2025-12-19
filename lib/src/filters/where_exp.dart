class WhereExp {
  static List<Object?> filter(List input, String varName, String expr) {
    final out = <Object?>[];

    for (final item in input) {
      final ok = _eval(expr, varName, item);
      if (ok) out.add(item);
    }

    return out;
  }

  static bool _eval(String expr, String varName, Object? item) {
    final t = expr.trim();
    if (t.isEmpty) return false;

    // OR split
    final orParts = _splitByKeywordTopLevel(t, "or");
    if (orParts.length > 1) {
      for (final p in orParts) {
        if (_eval(p, varName, item)) return true;
      }
      return false;
    }

    // AND split
    final andParts = _splitByKeywordTopLevel(t, "and");
    if (andParts.length > 1) {
      for (final p in andParts) {
        if (!_eval(p, varName, item)) return false;
      }
      return true;
    }

    // NOT
    if (t.startsWith("not ")) {
      return !_eval(t.substring(4), varName, item);
    }

    // comparison
    final m = RegExp(r"^(.*?)(==|!=|>=|<=|>|<)(.*)$").firstMatch(t);
    if (m != null) {
      final left = _value(m.group(1)!.trim(), varName, item);
      final op = m.group(2)!;
      final right = _value(m.group(3)!.trim(), varName, item);
      return _compare(left, right, op);
    }

    final v = _value(t, varName, item);
    return _truthy(v);
  }

  static List<String> _splitByKeywordTopLevel(String s, String kw) {
    final out = <String>[];
    final buf = StringBuffer();

    String? quote;
    var depth = 0;

    bool isWordChar(String c) {
      final cu = c.codeUnitAt(0);
      return (cu >= 65 && cu <= 90) ||
          (cu >= 97 && cu <= 122) ||
          (cu >= 48 && cu <= 57) ||
          cu == 95;
    }

    void flush() {
      final v = buf.toString().trim();
      if (v.isNotEmpty) out.add(v);
      buf.clear();
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
        if (i + kw.length <= s.length && s.substring(i, i + kw.length) == kw) {
          final before = i == 0 ? null : s[i - 1];
          final after = (i + kw.length) >= s.length ? null : s[i + kw.length];

          final beforeOk = before == null || !isWordChar(before);
          final afterOk = after == null || !isWordChar(after);

          if (beforeOk && afterOk) {
            flush();
            i += kw.length - 1;
            continue;
          }
        }
      }

      buf.write(ch);
    }

    flush();
    return out;
  }

  static Object? _value(String raw, String varName, Object? item) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    if ((s.startsWith("'") && s.endsWith("'")) ||
        (s.startsWith('"') && s.endsWith('"'))) {
      return s.substring(1, s.length - 1);
    }

    final lower = s.toLowerCase();
    if (lower == "true") return true;
    if (lower == "false") return false;
    if (lower == "nil" || lower == "null") return null;

    final n = num.tryParse(s);
    if (n != null) return n;

    // variable access
    if (s == varName) return item;

    if (s.startsWith("\$")) {
      // unsupported
      return null;
    }

    if (s.startsWith("\$")) return null;

    if (s.startsWith("$varName.")) {
      return _getProp(item, s.substring(varName.length + 1));
    }

    // bare identifier -> treat as property on item
    if (RegExp(
      r"^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$",
    ).hasMatch(s)) {
      return _getProp(item, s);
    }

    return null;
  }

  static Object? _getProp(Object? item, String path) {
    var cur = item;
    final parts = path.split(".");
    for (final p in parts) {
      final key = p.trim();
      if (key.isEmpty) return null;
      if (cur == null) return null;

      if (cur is Map) {
        cur = cur[key];
        continue;
      }
      return null;
    }
    return cur;
  }

  static num? _tryNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return num.tryParse((v ?? "").toString().trim());
  }

  static bool _compare(Object? a, Object? b, String op) {
    final an = _tryNum(a);
    final bn = _tryNum(b);

    if (an != null && bn != null) {
      switch (op) {
        case "==":
          return an == bn;
        case "!=":
          return an != bn;
        case ">":
          return an > bn;
        case ">=":
          return an >= bn;
        case "<":
          return an < bn;
        case "<=":
          return an <= bn;
      }
    }

    final as = a?.toString();
    final bs = b?.toString();

    switch (op) {
      case "==":
        return as == bs;
      case "!=":
        return as != bs;
    }

    // for > comparisons on non-numbers, false
    return false;
  }

  static bool _truthy(Object? v) => v != null && v != false;
}
