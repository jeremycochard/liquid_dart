import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("cycle alternates values", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% cycle 'a', 'b' %}{% cycle 'a', 'b' %}{% cycle 'a', 'b' %}",
      {},
    );
    expect(out, "aba");
  });

  test("cycle supports group", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% cycle g: 'a', 'b' %}{% cycle g: 'a', 'b' %}{% cycle h: 'x', 'y' %}{% cycle g: 'a', 'b' %}{% cycle h: 'x', 'y' %}",
      {},
    );
    expect(out, "abxay");
  });
}
