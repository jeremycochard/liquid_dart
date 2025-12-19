import "../errors/liquid_error.dart";
import "token.dart";

class Lexer {
  final String source;

  Lexer(this.source);

  List<Token> tokenize() {
    final tokens = <Token>[];
    var i = 0;

    var line = 1;
    var col = 1;

    void advance(int from, int to) {
      var k = from;
      while (k < to) {
        final cu = source.codeUnitAt(k);

        // CRLF ou CR seul
        if (cu == 13) {
          if (k + 1 < to && source.codeUnitAt(k + 1) == 10) {
            k++;
          }
          line++;
          col = 1;
          k++;
          continue;
        }

        // LF
        if (cu == 10) {
          line++;
          col = 1;
          k++;
          continue;
        }

        col++;
        k++;
      }
    }

    void addToken(TokenType type, String content, int offset, int l, int c) {
      tokens.add(Token(type, content, offset: offset, line: l, col: c));
    }

    int findCloseOutsideQuotes(int start, String seq) {
      String? quote;
      var escaped = false;

      for (var j = start; j <= source.length - seq.length; j++) {
        final ch = source[j];

        if (escaped) {
          escaped = false;
          continue;
        }

        if (quote != null) {
          if (ch == r"\") {
            escaped = true;
            continue;
          }
          if (ch == quote) {
            quote = null;
          }
          continue;
        }

        if (ch == "'" || ch == '"') {
          quote = ch;
          continue;
        }

        if (source.startsWith(seq, j)) {
          return j;
        }
      }

      return -1;
    }

    void trimLeftOfLastTextToken() {
      if (tokens.isEmpty) return;
      final last = tokens.last;
      if (last.type != TokenType.text) return;

      final trimmed = last.content.replaceFirst(RegExp(r"[ \t\r\n]+$"), "");
      tokens[tokens.length - 1] = Token(
        TokenType.text,
        trimmed,
        offset: last.offset,
        line: last.line,
        col: last.col,
      );
    }

    int skipWhitespaceForward(int idx) {
      var j = idx;
      while (j < source.length) {
        final c = source.codeUnitAt(j);
        if (c == 32 || c == 9 || c == 10 || c == 13) {
          j++;
          continue;
        }
        break;
      }
      return j;
    }

    while (i < source.length) {
      final nextOut = source.indexOf("{{", i);
      final nextTag = source.indexOf("{%", i);

      int next;
      TokenType? nextType;

      if (nextOut == -1 && nextTag == -1) {
        next = -1;
      } else if (nextOut == -1) {
        next = nextTag;
        nextType = TokenType.tag;
      } else if (nextTag == -1) {
        next = nextOut;
        nextType = TokenType.output;
      } else if (nextOut < nextTag) {
        next = nextOut;
        nextType = TokenType.output;
      } else {
        next = nextTag;
        nextType = TokenType.tag;
      }

      if (next == -1) {
        addToken(TokenType.text, source.substring(i), i, line, col);
        break;
      }

      if (next > i) {
        final startOffset = i;
        final startLine = line;
        final startCol = col;

        addToken(
          TokenType.text,
          source.substring(i, next),
          startOffset,
          startLine,
          startCol,
        );
        advance(i, next);
        i = next;
      }

      if (nextType == TokenType.output) {
        final startOffset = i;
        final startLine = line;
        final startCol = col;

        // opening: {{ or {{-
        final leftTrim = (i + 2 < source.length && source[i + 2] == "-");
        final openLen = leftTrim ? 3 : 2;

        final close = findCloseOutsideQuotes(i + openLen, "}}");
        if (close == -1) {
          throw LiquidParseError(
            "Unclosed output tag",
            location: Token(
              TokenType.output,
              "",
              offset: startOffset,
              line: startLine,
              col: startCol,
            ).location,
          );
        }

        final rightTrim = (close - 1 >= 0 && source[close - 1] == "-");

        if (leftTrim) trimLeftOfLastTextToken();

        final innerStart = i + openLen;
        final innerEnd = rightTrim ? close - 1 : close;
        final inner = source.substring(innerStart, innerEnd);

        addToken(TokenType.output, inner, startOffset, startLine, startCol);

        final consumedEnd = close + 2;
        advance(i, consumedEnd);
        i = consumedEnd;

        if (rightTrim) {
          final j = skipWhitespaceForward(i);
          advance(i, j);
          i = j;
        }
        continue;
      }

      if (nextType == TokenType.tag) {
        final startOffset = i;
        final startLine = line;
        final startCol = col;

        // opening: {% or {%-
        final leftTrim = (i + 2 < source.length && source[i + 2] == "-");
        final openLen = leftTrim ? 3 : 2;

        final close = findCloseOutsideQuotes(i + openLen, "%}");
        if (close == -1) {
          throw LiquidParseError(
            "Unclosed tag",
            location: Token(
              TokenType.tag,
              "",
              offset: startOffset,
              line: startLine,
              col: startCol,
            ).location,
          );
        }

        final rightTrim = (close - 1 >= 0 && source[close - 1] == "-");

        if (leftTrim) trimLeftOfLastTextToken();

        final innerStart = i + openLen;
        final innerEnd = rightTrim ? close - 1 : close;
        final inner = source.substring(innerStart, innerEnd);
        final trimmed = inner.trim();

        final tagConsumedEnd = close + 2;

        // avance jusqu’au début du contenu (après %})
        advance(i, tagConsumedEnd);
        i = tagConsumedEnd;

        if (rightTrim) {
          final j = skipWhitespaceForward(i);
          advance(i, j);
          i = j;
        }

        if (RegExp(r"^raw\s*$").hasMatch(trimmed)) {
          final endRe = RegExp(r"{%-?\s*endraw\s*-?%}");
          final sub = source.substring(i);
          final m = endRe.firstMatch(sub);
          if (m == null) {
            throw LiquidParseError(
              "Missing endraw",
              location: Token(
                TokenType.tag,
                "",
                offset: startOffset,
                line: startLine,
                col: startCol,
              ).location,
            );
          }

          final endTagText = sub.substring(m.start, m.end);
          final endLeftTrim = endTagText.startsWith("{%-");
          final endRightTrim = endTagText.contains("-%}");

          var rawText = sub.substring(0, m.start);
          if (endLeftTrim) {
            rawText = rawText.replaceFirst(RegExp(r"[ \t\r\n]+$"), "");
          }

          if (rawText.isNotEmpty) {
            final rawStartOffset = i;
            final rawStartLine = line;
            final rawStartCol = col;

            addToken(
              TokenType.text,
              rawText,
              rawStartOffset,
              rawStartLine,
              rawStartCol,
            );
            advance(i, i + rawText.length);
            i = i + rawText.length;
          }

          // consomme le endraw tag
          advance(i, i + (m.end - m.start));
          i = i + (m.end - m.start);

          if (endRightTrim) {
            final j = skipWhitespaceForward(i);
            advance(i, j);
            i = j;
          }

          continue;
        }

        if (RegExp(r"^comment\b").hasMatch(trimmed)) {
          final endRe = RegExp(r"{%-?\s*endcomment\s*-?%}");
          final sub = source.substring(i);
          final m = endRe.firstMatch(sub);
          if (m == null) {
            throw LiquidParseError(
              "Missing endcomment",
              location: Token(
                TokenType.tag,
                "",
                offset: startOffset,
                line: startLine,
                col: startCol,
              ).location,
            );
          }

          final endTagText = sub.substring(m.start, m.end);
          final endRightTrim = endTagText.contains("-%}");

          // saute tout le contenu du comment + endcomment tag
          advance(i, i + m.end);
          i = i + m.end;

          if (endRightTrim) {
            final j = skipWhitespaceForward(i);
            advance(i, j);
            i = j;
          }

          continue;
        }

        // tag normal
        addToken(TokenType.tag, inner, startOffset, startLine, startCol);
        continue;
      }
    }

    return tokens;
  }
}
