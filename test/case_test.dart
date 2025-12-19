import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("case when else", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% case n %}{% when 1 %}one{% when 2 or 3 %}two{% else %}other{% endcase %}",
      {"n": 3},
    );
    expect(out, "two");
  });

  test("case matches string literal", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{% case name %}{% when "Ada" %}hit{% else %}miss{% endcase %}',
      {"name": "Ada"},
    );
    expect(out, "hit");
  });

  test("case numeric coercion", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% case n %}{% when 2 %}two{% else %}other{% endcase %}",
      {"n": "2"},
    );
    expect(out, "two");
  });
}
