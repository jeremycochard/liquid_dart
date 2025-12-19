import "../errors/liquid_error.dart";
import "liquid_filesystem.dart";

class InMemoryFileSystem implements LiquidFileSystem {
  final Map<String, String> templates;

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
