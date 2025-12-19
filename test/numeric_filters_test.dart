import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("plus minus times", () async {
    final engine = LiquidEngine();
    expect(await engine.parseAndRender("{{ 2 | plus: 3 }}", {}), "5");
    expect(await engine.parseAndRender("{{ 7 | minus: 2 }}", {}), "5");
    expect(await engine.parseAndRender("{{ 2 | times: 3 }}", {}), "6");
  });

  test("divided_by integer division", () async {
    final engine = LiquidEngine();
    expect(await engine.parseAndRender("{{ 5 | divided_by: 2 }}", {}), "2");
  });

  test("modulo", () async {
    final engine = LiquidEngine();
    expect(await engine.parseAndRender("{{ 5 | modulo: 2 }}", {}), "1");
  });

  test("round floor ceil abs", () async {
    final engine = LiquidEngine();
    expect(await engine.parseAndRender("{{ -3 | abs }}", {}), "3");
    expect(await engine.parseAndRender("{{ 1.9 | floor }}", {}), "1");
    expect(await engine.parseAndRender("{{ 1.1 | ceil }}", {}), "2");
    expect(await engine.parseAndRender("{{ 1.234 | round: 2 }}", {}), "1.23");
  });
}
