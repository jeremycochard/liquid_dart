import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("string literal", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ "Ada" }}', {});
    expect(out, "Ada");
  });

  test("number literal", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{{ 2 }}", {});
    expect(out, "2");
  });

  test("upcase filter", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{{ name | upcase }}", {
      "name": "Ada",
    });
    expect(out, "ADA");
  });

  test("append filter", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ name | append: "!" }}', {
      "name": "Ada",
    });
    expect(out, "Ada!");
  });

  test("default filter uses fallback on missing", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ missing | default: "x" }}', {});
    expect(out, "x");
  });

  test("unknown filter throws when strictFilters is true", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(strictFilters: true),
    );
    expect(
      () =>
          engine.parseAndRender("{{ name | no_such_filter }}", {"name": "Ada"}),
      throwsA(isA<LiquidRenderError>()),
    );
  });

  test("strictVariables does not throw if filters produce a value", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(strictVariables: true),
    );
    final out = await engine.parseAndRender('{{ missing | default: "x" }}', {});
    expect(out, "x");
  });
}
