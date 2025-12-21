import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("error toString contains line and caret", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(strictVariables: true),
    );
    try {
      await engine.parseAndRender("A {{ missing }} B", {});
      fail("should throw");
    } catch (e) {
      expect(e.toString(), contains("A {{ missing }} B"));
      expect(e.toString(), contains("^"));
    }
  });
}
