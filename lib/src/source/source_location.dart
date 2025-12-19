class SourceLocation {
  final int offset;
  final int line;
  final int col;

  final String? sourceLine;

  const SourceLocation({
    required this.offset,
    required this.line,
    required this.col,
    this.sourceLine,
  });

  SourceLocation withLine(String? lineText) {
    return SourceLocation(
      offset: offset,
      line: line,
      col: col,
      sourceLine: lineText,
    );
  }

  @override
  String toString() => "$line:$col";
}
