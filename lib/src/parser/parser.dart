import "../ast/node.dart";
import "../conditions/condition.dart";
import "../errors/liquid_error.dart";
import "../expressions/expression.dart";
import "../expressions/output_expression.dart";
import "../lexer/token.dart";
import "../source/source_location.dart";

class Parser {
  late final List<Token> _tokens;
  int _i = 0;

  List<Node> parse(List<Token> tokens) {
    _tokens = tokens;
    _i = 0;
    final nodes = _parseNodes(stopTags: const {});
    if (_i != _tokens.length) {
      final t = _tokens[_i];
      throw LiquidParseError(
        "Unexpected tag: ${t.content.trim()}",
        location: t.location,
      );
    }
    return nodes;
  }

  CaptureNode _parseCapture(String inner) {
    final name = inner.substring(7).trim();
    if (!_isIdent(name)) throw LiquidParseError("Invalid capture tag: $inner");

    _i++;
    final body = _parseNodes(stopTags: {"endcapture"});

    if (_i >= _tokens.length ||
        _tokens[_i].type != TokenType.tag ||
        _firstWord(_tokens[_i].content.trim()) != "endcapture") {
      throw LiquidParseError("Missing endcapture");
    }

    _i++;
    return CaptureNode(name: name, body: body);
  }

  static bool _isIdent(String s) {
    return RegExp(r"^[A-Za-z_][A-Za-z0-9_]*$").hasMatch(s);
  }

  PartialNode _parsePartial(
    String inner, {
    required bool isolate,
    required String keyword,
    required SourceLocation loc,
  }) {
    final rest = inner.substring(keyword.length).trim();
    if (rest.isEmpty) {
      throw LiquidParseError("Invalid $keyword tag: $inner");
    }

    final parts = _splitTopLevelCommas(rest);
    if (parts.isEmpty) {
      throw LiquidParseError("Invalid $keyword tag: $inner");
    }

    final nameExpr = Expression.parse(parts.first);

    final args = <String, Expression>{};
    for (var i = 1; i < parts.length; i++) {
      final p = parts[i].trim();
      if (p.isEmpty) continue;

      final idx = p.indexOf(":");
      if (idx <= 0) {
        throw LiquidParseError("Invalid $keyword argument: $p");
      }

      final key = p.substring(0, idx).trim();
      final valueRaw = p.substring(idx + 1).trim();

      if (!_isIdent(key) || valueRaw.isEmpty) {
        throw LiquidParseError("Invalid $keyword argument: $p");
      }

      args[key] = Expression.parse(valueRaw);
    }

    return PartialNode(
      isolate: isolate,
      nameExpr: nameExpr,
      namedArgs: args,
      location: loc,
    );
  }

  static List<String> _splitTopLevelCommas(String s) {
    final out = <String>[];
    final buf = StringBuffer();

    String? quote;
    var depth = 0;

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

      if (depth == 0 && ch == ",") {
        flush();
        continue;
      }

      buf.write(ch);
    }

    flush();
    return out;
  }

  List<Node> _parseNodes({required Set<String> stopTags}) {
    final nodes = <Node>[];

    while (_i < _tokens.length) {
      final t = _tokens[_i];

      switch (t.type) {
        case TokenType.text:
          if (t.content.isNotEmpty) nodes.add(TextNode(t.content));
          _i++;
          continue;

        case TokenType.output:
          final raw = t.content.trim();
          try {
            final expr = OutputExpression.parse(raw);
            nodes.add(OutputNode(raw: raw, expr: expr, location: t.location));
          } on LiquidError catch (e) {
            if (e.location != null) rethrow;
            throw LiquidParseError(e.message, location: t.location);
          }
          _i++;
          continue;

        case TokenType.tag:
          final inner = t.content.trim();
          final tagName = _firstWord(inner);

          if (stopTags.contains(tagName)) {
            return nodes;
          }

          if (tagName == "assign") {
            nodes.add(_parseAssign(inner, t.location));
            _i++;
            continue;
          }

          if (tagName == "if") {
            nodes.add(_parseIf(inner));
            continue;
          }

          if (tagName == "unless") {
            nodes.add(_parseUnless(inner));
            continue;
          }

          if (tagName == "cycle") {
            nodes.add(_parseCycle(inner));
            continue;
          }

          if (tagName == "case") {
            nodes.add(_parseCase(inner));
            continue;
          }

          if (tagName == "layout") {
            nodes.add(_parseLayout(inner, t.location));
            _i++;
            continue;
          }

          if (tagName == "block") {
            nodes.add(_parseBlock(inner));
            continue;
          }

          if (tagName == "for") {
            nodes.add(_parseFor(inner));
            continue;
          }

          if (tagName == "break") {
            _i++;
            nodes.add(BreakNode());
            continue;
          }

          if (tagName == "continue") {
            _i++;
            nodes.add(ContinueNode());
            continue;
          }

          if (tagName == "capture") {
            nodes.add(_parseCapture(inner));
            continue;
          }

          if (tagName == "increment") {
            final name = inner.substring(9).trim();
            if (!_isIdent(name)) {
              throw LiquidParseError("Invalid increment tag: $inner");
            }
            _i++;
            nodes.add(IncrementNode(name));
            continue;
          }

          if (tagName == "decrement") {
            final name = inner.substring(9).trim();
            if (!_isIdent(name)) {
              throw LiquidParseError("Invalid decrement tag: $inner");
            }
            _i++;
            nodes.add(DecrementNode(name));
            continue;
          }

          if (tagName == "liquid") {
            final expanded = _expandLiquidTag(inner, t.location);
            _tokens.removeAt(_i);
            _tokens.insertAll(_i, expanded);
            continue;
          }

          if (tagName == "include") {
            nodes.add(
              _parsePartial(
                inner,
                isolate: false,
                keyword: "include",
                loc: t.location,
              ),
            );
            _i++;
            continue;
          }

          if (tagName == "render") {
            nodes.add(
              _parsePartial(
                inner,
                isolate: true,
                keyword: "render",
                loc: t.location,
              ),
            );
            _i++;
            continue;
          }

          if (tagName == "tablerow") {
            nodes.add(_parseTableRow(inner));
            continue;
          }

          throw LiquidParseError(
            "Tags not supported yet: $inner",
            location: t.location,
          );
      }
    }

    return nodes;
  }

  List<Token> _expandLiquidTag(String inner, SourceLocation loc) {
    var body = inner.trim();
    body = body.substring("liquid".length).trimLeft();

    if (body.isEmpty) {
      return const <Token>[];
    }

    final stmts = _splitLiquidStatements(body);

    final out = <Token>[];
    for (final s in stmts) {
      final line = s.trim();
      if (line.isEmpty) continue;

      if (line.startsWith("echo ")) {
        final expr = line.substring(5).trim();
        out.add(
          Token(
            TokenType.output,
            expr,
            offset: loc.offset,
            line: loc.line,
            col: loc.col,
          ),
        );
        continue;
      }

      out.add(
        Token(
          TokenType.tag,
          line,
          offset: loc.offset,
          line: loc.line,
          col: loc.col,
        ),
      );
    }
    return out;
  }

  static List<String> _splitLiquidStatements(String s) {
    final out = <String>[];
    final buf = StringBuffer();

    String? quote;
    var depth = 0;

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
        if (ch == "\n" || ch == ";") {
          flush();
          continue;
        }
        if (ch == "\r") {
          // ignore CR, newline géré sur \n
          continue;
        }
      }

      buf.write(ch);
    }

    flush();
    return out;
  }

  CycleNode _parseCycle(String inner) {
    var rest = inner.substring(5).trim();
    if (rest.isEmpty) throw LiquidParseError("Invalid cycle tag: $inner");

    String group = "";

    final gm = RegExp(
      r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+)$",
      dotAll: true,
    ).firstMatch(rest);
    if (gm != null) {
      group = gm.group(1)!;
      rest = gm.group(2)!.trim();
    }

    final parts = _splitTopLevelCommas(rest);
    if (parts.isEmpty) throw LiquidParseError("Invalid cycle tag: $inner");

    final values = parts.map(Expression.parse).toList(growable: false);

    _i++;
    return CycleNode(group: group, values: values);
  }

  TableRowNode _parseTableRow(String inner) {
    final m = RegExp(
      r"^tablerow\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+)$",
      dotAll: true,
    ).firstMatch(inner);
    if (m == null) throw LiquidParseError("Invalid tablerow tag: $inner");

    final itemName = m.group(1)!;
    final rest = m.group(2)!.trim();
    if (rest.isEmpty) throw LiquidParseError("Invalid tablerow tag: $inner");

    final (collectionRaw, modifiersRaw) = _splitForRest(rest);
    final collectionExpr = OutputExpression.parse(collectionRaw);

    Expression? colsExpr;
    Expression? limitExpr;
    Expression? offsetExpr;

    if (modifiersRaw != null && modifiersRaw.trim().isNotEmpty) {
      final mod = modifiersRaw;

      final cm = RegExp(r"\bcols\s*:\s*([^\s]+)").firstMatch(mod);
      if (cm != null) {
        colsExpr = Expression.parse(cm.group(1)!);
      }

      final lm = RegExp(r"\blimit\s*:\s*([^\s]+)").firstMatch(mod);
      if (lm != null) {
        limitExpr = Expression.parse(lm.group(1)!);
      }

      final om = RegExp(r"\boffset\s*:\s*([^\s]+)").firstMatch(mod);
      if (om != null) {
        offsetExpr = Expression.parse(om.group(1)!);
      }
    }

    _i++;

    final body = _parseNodes(stopTags: {"endtablerow"});

    if (_i >= _tokens.length ||
        _tokens[_i].type != TokenType.tag ||
        _firstWord(_tokens[_i].content.trim()) != "endtablerow") {
      throw LiquidParseError("Missing endtablerow");
    }

    _i++;

    return TableRowNode(
      itemName: itemName,
      collectionExpr: collectionExpr,
      colsExpr: colsExpr,
      limitExpr: limitExpr,
      offsetExpr: offsetExpr,
      body: body,
    );
  }

  LayoutNode _parseLayout(String inner, SourceLocation loc) {
    final rest = inner.substring(6).trim();
    if (rest.isEmpty) {
      throw LiquidParseError("Invalid layout tag: $inner", location: loc);
    }
    return LayoutNode(nameExpr: Expression.parse(rest), location: loc);
  }

  BlockNode _parseBlock(String inner) {
    final name = inner.substring(5).trim();
    if (!_isIdent(name)) throw LiquidParseError("Invalid block tag: $inner");

    _i++;
    final body = _parseNodes(stopTags: {"endblock"});

    if (_i >= _tokens.length ||
        _tokens[_i].type != TokenType.tag ||
        _firstWord(_tokens[_i].content.trim()) != "endblock") {
      throw LiquidParseError("Missing endblock");
    }

    _i++;
    return BlockNode(name: name, body: body);
  }

  AssignNode _parseAssign(String inner, SourceLocation loc) {
    final m = RegExp(
      r"^assign\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$",
      dotAll: true,
    ).firstMatch(inner);

    if (m == null) {
      throw LiquidParseError("Invalid assign tag: $inner");
    }

    final name = m.group(1)!;
    final rhs = m.group(2)!.trim();
    if (rhs.isEmpty) throw LiquidParseError("Invalid assign tag: $inner");

    final expr = OutputExpression.parse(rhs);
    return AssignNode(name: name, valueExpr: expr, location: loc);
  }

  IfNode _parseIf(String inner) {
    final condRaw = inner.substring(2).trim();
    if (condRaw.isEmpty) throw LiquidParseError("Invalid if tag: $inner");

    _i++;

    final branches = <IfBranch>[];

    final firstBody = _parseNodes(stopTags: {"elsif", "else", "endif"});
    branches.add(
      IfBranch(condition: Condition.parse(condRaw), body: firstBody),
    );

    var sawElse = false;

    while (_i < _tokens.length) {
      final t = _tokens[_i];
      if (t.type != TokenType.tag) throw LiquidParseError("Expected endif");

      final tagInner = t.content.trim();
      final tagName = _firstWord(tagInner);

      if (tagName == "elsif") {
        if (sawElse) throw LiquidParseError("elsif after else is not allowed");
        final c = tagInner.substring(5).trim();
        if (c.isEmpty) throw LiquidParseError("Invalid elsif tag: $tagInner");
        _i++;
        final body = _parseNodes(stopTags: {"elsif", "else", "endif"});
        branches.add(IfBranch(condition: Condition.parse(c), body: body));
        continue;
      }

      if (tagName == "else") {
        if (sawElse) throw LiquidParseError("Multiple else in if block");
        sawElse = true;
        _i++;
        final body = _parseNodes(stopTags: {"endif"});
        branches.add(IfBranch(condition: null, body: body));
        continue;
      }

      if (tagName == "endif") {
        _i++;
        return IfNode(branches: branches);
      }

      throw LiquidParseError("Unexpected tag in if block: $tagInner");
    }

    throw LiquidParseError("Missing endif");
  }

  IfNode _parseUnless(String inner) {
    final condRaw = inner.substring(6).trim();
    if (condRaw.isEmpty) throw LiquidParseError("Invalid unless tag: $inner");

    _i++;

    final branches = <IfBranch>[];

    final firstBody = _parseNodes(stopTags: {"elsif", "else", "endunless"});
    branches.add(
      IfBranch(
        condition: NotCondition(Condition.parse(condRaw)),
        body: firstBody,
      ),
    );

    var sawElse = false;

    while (_i < _tokens.length) {
      final t = _tokens[_i];
      if (t.type != TokenType.tag) throw LiquidParseError("Expected endunless");

      final tagInner = t.content.trim();
      final tagName = _firstWord(tagInner);

      if (tagName == "elsif") {
        if (sawElse) throw LiquidParseError("elsif after else is not allowed");
        final c = tagInner.substring(5).trim();
        if (c.isEmpty) throw LiquidParseError("Invalid elsif tag: $tagInner");
        _i++;
        final body = _parseNodes(stopTags: {"elsif", "else", "endunless"});
        branches.add(IfBranch(condition: Condition.parse(c), body: body));
        continue;
      }

      if (tagName == "else") {
        if (sawElse) throw LiquidParseError("Multiple else in unless block");
        sawElse = true;
        _i++;
        final body = _parseNodes(stopTags: {"endunless"});
        branches.add(IfBranch(condition: null, body: body));
        continue;
      }

      if (tagName == "endunless") {
        _i++;
        return IfNode(branches: branches);
      }

      throw LiquidParseError("Unexpected tag in unless block: $tagInner");
    }

    throw LiquidParseError("Missing endunless");
  }

  CaseNode _parseCase(String inner) {
    final raw = inner.substring(4).trim();
    if (raw.isEmpty) throw LiquidParseError("Invalid case tag: $inner");

    final valueExpr = Expression.parse(raw);
    _i++;

    final branches = <CaseBranch>[];
    List<Node>? elseBody;

    while (_i < _tokens.length) {
      final t = _tokens[_i];
      if (t.type != TokenType.tag) {
        throw LiquidParseError("Expected when/else/endcase");
      }

      final tagInner = t.content.trim();
      final tagName = _firstWord(tagInner);

      if (tagName == "when") {
        final whenRaw = tagInner.substring(4).trim();
        if (whenRaw.isEmpty) {
          throw LiquidParseError("Invalid when tag: $tagInner");
        }

        final valueRaws = _splitWhenValues(whenRaw);
        final values = valueRaws.map(Expression.parse).toList(growable: false);

        _i++;
        final body = _parseNodes(stopTags: {"when", "else", "endcase"});
        branches.add(CaseBranch(values: values, body: body));
        continue;
      }

      if (tagName == "else") {
        _i++;
        elseBody = _parseNodes(stopTags: {"endcase"});
        continue;
      }

      if (tagName == "endcase") {
        _i++;
        return CaseNode(
          valueExpr: valueExpr,
          branches: branches,
          elseBody: elseBody,
        );
      }

      throw LiquidParseError("Unexpected tag in case block: $tagInner");
    }

    throw LiquidParseError("Missing endcase");
  }

  ForNode _parseFor(String inner) {
    final m = RegExp(
      r"^for\s+([A-Za-z_][A-Za-z0-9_]*)\s+in\s+(.+)$",
      dotAll: true,
    ).firstMatch(inner);
    if (m == null) throw LiquidParseError("Invalid for tag: $inner");

    final itemName = m.group(1)!;
    final rest = m.group(2)!.trim();
    if (rest.isEmpty) throw LiquidParseError("Invalid for tag: $inner");

    final (collectionRaw, modifiersRaw) = _splitForRest(rest);
    final collectionExpr = OutputExpression.parse(collectionRaw);

    Expression? limitExpr;
    Expression? offsetExpr;
    var reversed = false;

    if (modifiersRaw != null && modifiersRaw.trim().isNotEmpty) {
      final mod = modifiersRaw;

      reversed = RegExp(r"\breversed\b").hasMatch(mod);

      final lm = RegExp(r"\blimit\s*:\s*([^\s]+)").firstMatch(mod);
      if (lm != null) limitExpr = Expression.parse(lm.group(1)!);

      final om = RegExp(r"\boffset\s*:\s*([^\s]+)").firstMatch(mod);
      if (om != null) offsetExpr = Expression.parse(om.group(1)!);
    }

    _i++;

    final body = _parseNodes(stopTags: {"else", "endfor"});
    List<Node>? elseBody;

    if (_i < _tokens.length &&
        _tokens[_i].type == TokenType.tag &&
        _firstWord(_tokens[_i].content.trim()) == "else") {
      _i++;
      elseBody = _parseNodes(stopTags: {"endfor"});
    }

    if (_i >= _tokens.length ||
        _tokens[_i].type != TokenType.tag ||
        _firstWord(_tokens[_i].content.trim()) != "endfor") {
      throw LiquidParseError("Missing endfor");
    }

    _i++;

    return ForNode(
      itemName: itemName,
      collectionExpr: collectionExpr,
      limitExpr: limitExpr,
      offsetExpr: offsetExpr,
      reversed: reversed,
      body: body,
      elseBody: elseBody,
    );
  }

  static List<String> _splitWhenValues(String s) {
    final parts = <String>[];
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
      if (v.isNotEmpty) parts.add(v);
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
        if (ch == ",") {
          flush();
          continue;
        }

        const kw = "or";
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
    return parts;
  }

  static (String, String?) _splitForRest(String s) {
    String? quote;
    var depth = 0;

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

      if (depth == 0 && ch.trim().isEmpty) {
        var j = i;
        while (j < s.length && s[j].trim().isEmpty) {
          j++;
        }
        final rest = s.substring(j);

        final startsModifier =
            rest.startsWith("limit") ||
            rest.startsWith("offset") ||
            rest.startsWith("reversed") ||
            rest.startsWith("cols");

        if (startsModifier) {
          final left = s.substring(0, i).trim();
          final right = s.substring(j).trim();
          return (left, right);
        }
      }
    }

    return (s.trim(), null);
  }

  static String _firstWord(String s) {
    final m = RegExp(r"^([A-Za-z_][A-Za-z0-9_]*)").firstMatch(s);
    return m?.group(1) ?? s;
  }
}
