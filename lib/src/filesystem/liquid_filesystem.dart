import "../errors/liquid_error.dart";

/// Provides template source text for `{% include %}` and `{% render %}`.
abstract class LiquidFileSystem {
  /// Reads a template by name and returns its source text.
  Future<String> readTemplate(String name);
}

/// Filesystem that always errors, used as a safe default.
class NoopFileSystem implements LiquidFileSystem {
  @override
  Future<String> readTemplate(String name) async {
    throw LiquidRenderError("No filesystem configured (cannot load: $name)");
  }
}
