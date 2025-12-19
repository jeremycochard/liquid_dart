import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("output left trim", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("A \n {{- x }}B", {"x": "1"});
    expect(out, "A1B");
  });

  test("output right trim", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("A{{ x -}} \n B", {"x": "1"});
    expect(out, "A1B");
  });

  test("tag left trim", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "A \n {%- assign x = 1 %}{{ x }}",
      {},
    );
    expect(out, "A1");
  });

  test("tag right trim", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% assign x = 1 -%} \n {{ x }}",
      {},
    );
    expect(out, "1");
  });
}
