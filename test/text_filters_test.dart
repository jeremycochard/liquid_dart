import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("strip lstrip rstrip", () async {
    final engine = LiquidEngine();
    expect(await engine.parseAndRender('{{ "  a  " | strip }}', {}), "a");
    expect(await engine.parseAndRender('{{ "  a  " | lstrip }}', {}), "a  ");
    expect(await engine.parseAndRender('{{ "  a  " | rstrip }}', {}), "  a");
  });

  test("replace remove", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "ababa" | replace: "a", "x" }}', {}),
      "xbxbx",
    );
    expect(
      await engine.parseAndRender(
        '{{ "ababa" | replace_first: "a", "x" }}',
        {},
      ),
      "xbaba",
    );
    expect(
      await engine.parseAndRender('{{ "ababa" | remove: "a" }}', {}),
      "bb",
    );
    expect(
      await engine.parseAndRender('{{ "ababa" | remove_first: "a" }}', {}),
      "baba",
    );
  });

  test("split join", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "a,b,c" | split: "," | join: "-" }}', {}),
      "a-b-c",
    );
  });

  test("slice", () async {
    final engine = LiquidEngine();
    expect(await engine.parseAndRender('{{ "abcd" | slice: 1, 2 }}', {}), "bc");
    expect(
      await engine.parseAndRender('{{ "abcd" | slice: -2, 2 }}', {}),
      "cd",
    );
  });

  test("strip_newlines", () async {
    final engine = LiquidEngine();
    expect(
      await engine.parseAndRender('{{ "a\nb\r\nc" | strip_newlines }}', {}),
      "abc",
    );
  });
}
