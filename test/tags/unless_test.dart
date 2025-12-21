import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("unless basic", () async {
    final engine = LiquidEngine();
    final out1 = await engine.parseAndRender(
      "{% unless ok %}A{% endunless %}",
      {"ok": false},
    );
    final out2 = await engine.parseAndRender(
      "{% unless ok %}A{% endunless %}",
      {"ok": true},
    );
    expect(out1, "A");
    expect(out2, "");
  });

  test("unless else", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% unless ok %}A{% else %}B{% endunless %}",
      {"ok": true},
    );
    expect(out, "B");
  });

  test("unless elsif", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% unless ok %}A{% elsif n == 1 %}B{% else %}C{% endunless %}",
      {"ok": true, "n": 1},
    );
    expect(out, "B");
  });
}
