import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("capture stores rendered content", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% capture x %}hi {{ name }}{% endcapture %}{{ x }}",
      {"name": "Ada"},
    );
    expect(out, "hi Ada");
  });

  test("capture can include tags", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% capture x %}{% if ok %}Y{% else %}N{% endif %}{% endcapture %}{{ x }}",
      {"ok": true},
    );
    expect(out, "Y");
  });

  test("increment outputs 0 then 1", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% increment a %},{% increment a %},{% increment a %}",
      {},
    );
    expect(out, "0,1,2");
  });

  test("decrement outputs -1 then -2", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% decrement a %},{% decrement a %}",
      {},
    );
    expect(out, "-1,-2");
  });
}
