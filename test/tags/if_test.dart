import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("if truthy variable", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{% if user %}yes{% endif %}", {
      "user": {"name": "Ada"},
    });
    expect(out, "yes");
  });

  test("if missing variable is false", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% if missing %}yes{% endif %}",
      {},
    );
    expect(out, "");
  });

  test("if else", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% if ok %}A{% else %}B{% endif %}",
      {"ok": false},
    );
    expect(out, "B");
  });

  test("elsif chain", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% if n == 1 %}one{% elsif n == 2 %}two{% else %}other{% endif %}",
      {"n": 2},
    );
    expect(out, "two");
  });

  test("comparisons and contains", () async {
    final engine = LiquidEngine();
    final out1 = await engine.parseAndRender(
      "{% if n > 1 and n <= 3 %}ok{% endif %}",
      {"n": 2},
    );
    expect(out1, "ok");

    final out2 = await engine.parseAndRender(
      '{% if name contains "da" %}hit{% endif %}',
      {"name": "Ada"},
    );
    expect(out2, "hit");
  });

  test("not and parentheses", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% if not (a == 1 or b == 2) %}yes{% endif %}",
      {"a": 2, "b": 3},
    );
    expect(out, "yes");
  });

  test("nested if", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% if ok %}X{% if inner %}Y{% endif %}{% endif %}",
      {"ok": true, "inner": true},
    );
    expect(out, "XY");
  });
}
