import "../source/source_location.dart";
import "../source/source_snipper.dart";

sealed class LiquidError implements Exception {
  final String message;
  final SourceLocation? location;

  const LiquidError(this.message, {this.location});

  @override
  String toString() {
    final loc = location;
    if (loc == null) return "LiquidError: $message";

    final lineText = loc.sourceLine;
    if (lineText == null) {
      return "LiquidError at ${loc.line}:${loc.col}: $message";
    }

    final caretPos = loc.col <= 1 ? 0 : loc.col - 1;
    final caret = "${" " * caretPos}^";

    return "LiquidError at ${loc.line}:${loc.col}: $message\n$lineText\n$caret";
  }

  static SourceLocation attachLine(SourceLocation loc, String source) {
    return loc.withLine(lineAtOffset(source, loc.offset));
  }
}

class LiquidParseError extends LiquidError {
  const LiquidParseError(super.message, {super.location});
}

class LiquidRenderError extends LiquidError {
  const LiquidRenderError(super.message, {super.location});
}
