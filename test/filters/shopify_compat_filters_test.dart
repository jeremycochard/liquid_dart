import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("handleize", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "Hello, World!" | handleize }}', {}),
      "hello-world",
    );
  });

  test("truncatewords", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "a b c d e" | truncatewords: 3 }}', {}),
      "a b c...",
    );
    expect(
      await engine.parseAndRender('{{ "a b c" | truncatewords: 3 }}', {}),
      "a b c",
    );
  });

  test("pluralize", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ 1 | pluralize: "item", "items" }}', {}),
      "item",
    );
    expect(
      await engine.parseAndRender('{{ 2 | pluralize: "item", "items" }}', {}),
      "items",
    );
  });

  test("money default format", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(moneyFormat: r"${{amount}}"),
    );
    expect(await engine.parseAndRender("{{ 12345 | money }}", {}), r"$123.45");
  });

  test("money with comma separator", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender(
        '{{ 123456 | money: "€{{amount_with_comma_separator}}" }}',
        {},
      ),
      "€1.234,56",
    );
  });
}
