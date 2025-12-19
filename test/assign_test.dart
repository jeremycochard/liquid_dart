import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("assign literal then output", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{% assign name = "Ada" %}hi {{ name }}',
      {},
    );
    expect(out, "hi Ada");
  });

  test("assign from variable", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{% assign x = name %}{{ x }}", {
      "name": "Lin",
    });
    expect(out, "Lin");
  });

  test("assign supports filters", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% assign x = name | upcase %}{{ x }}",
      {"name": "Ada"},
    );
    expect(out, "ADA");
  });

  test("assign does not mutate input data map", () async {
    final engine = LiquidEngine();
    final data = <String, Object?>{"name": "Ada"};
    final out = await engine.parseAndRender(
      "{% assign x = 1 %}{{ name }}",
      data,
    );
    expect(out, "Ada");
    expect(data.containsKey("x"), isFalse);
  });

  test("unknown tag throws parse error", () {
    final engine = LiquidEngine();
    expect(
      () => engine.parse("{% no_such_tag %}"),
      throwsA(isA<LiquidParseError>()),
    );
  });
}
