import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("escape and strip_html", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "<b>A&B</b>" | escape }}', {}),
      "&lt;b&gt;A&amp;B&lt;/b&gt;",
    );
    expect(
      await engine.parseAndRender('{{ "<b>A</b>" | strip_html }}', {}),
      "A",
    );
  });

  test("url_encode", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "a b" | url_encode }}', {}),
      "a%20b",
    );
  });

  test("truncate", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "abcdef" | truncate: 4 }}', {}),
      "a...",
    );
    expect(
      await engine.parseAndRender('{{ "abcdef" | truncate: 4, "." }}', {}),
      "abc.",
    );
    expect(await engine.parseAndRender('{{ "abc" | truncate: 4 }}', {}), "abc");
  });

  test("newline_to_br", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "a\nb" | newline_to_br }}', {}),
      "a<br />\nb",
    );
  });

  test("json", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ obj | json }}', {
      "obj": {"a": 1},
    });
    expect(out, '{"a":1}');
  });
}
