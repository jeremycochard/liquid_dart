import "../source/source_location.dart";

enum TokenType { text, output, tag }

class Token {
  final TokenType type;
  final String content;

  final int offset;
  final int line;
  final int col;

  const Token(
    this.type,
    this.content, {
    required this.offset,
    required this.line,
    required this.col,
  });

  SourceLocation get location =>
      SourceLocation(offset: offset, line: line, col: col);
}
