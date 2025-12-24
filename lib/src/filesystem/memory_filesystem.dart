import "../errors/liquid_error.dart";
import "liquid_filesystem.dart";

/// Simple in-memory filesystem backed by a map of templates.
class InMemoryFileSystem implements LiquidFileSystem {
  /// Template map keyed by name.
  final Map<String, String> templates;

  /// Creates a filesystem with the provided [templates].
  InMemoryFileSystem(this.templates);

  @override
  Future<String> readTemplate(String name) async {
    final v = templates[name];
    if (v == null) {
      throw LiquidRenderError("Template not found: $name");
    }
    return v;
  }
}
