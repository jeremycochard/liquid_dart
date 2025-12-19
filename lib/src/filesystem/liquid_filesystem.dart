import "../errors/liquid_error.dart";

abstract class LiquidFileSystem {
  Future<String> readTemplate(String name);
}

class NoopFileSystem implements LiquidFileSystem {
  @override
  Future<String> readTemplate(String name) async {
    throw LiquidRenderError("No filesystem configured (cannot load: $name)");
  }
}
