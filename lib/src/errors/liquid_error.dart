import "../source/source_location.dart";
import "../source/source_snipper.dart";

/// Base class for Liquid parsing and rendering errors.
sealed class LiquidError implements Exception {
  /// Human-readable error message.
  final String message;

  /// Optional source location associated with the error.
  final SourceLocation? location;

  /// Creates a new Liquid error with an optional source location.
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

  /// Attaches the source line text to a location for better error output.
  static SourceLocation attachLine(SourceLocation loc, String source) {
    return loc.withLine(lineAtOffset(source, loc.offset));
  }
}

/// Error raised when parsing fails.
class LiquidParseError extends LiquidError {
  const LiquidParseError(super.message, {super.location});
}

/// Error raised when rendering fails.
class LiquidRenderError extends LiquidError {
  const LiquidRenderError(super.message, {super.location});
}
