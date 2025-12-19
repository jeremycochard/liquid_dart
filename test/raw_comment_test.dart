import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("raw outputs literal braces", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{% raw %}{{ x }}{% endraw %}", {
      "x": "A",
    });
    expect(out, "{{ x }}");
  });

  test("raw outputs literal tags", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% raw %}{% if x %}Y{% endif %}{% endraw %}",
      {"x": true},
    );
    expect(out, "{% if x %}Y{% endif %}");
  });

  test("comment removes content entirely", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "A{% comment %}{{ x }}{% if y %}Z{% endif %}{% endcomment %}B",
      {"x": "X", "y": true},
    );
    expect(out, "AB");
  });
}
