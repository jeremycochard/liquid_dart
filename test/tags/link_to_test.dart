import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("link_to basic", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ "Home" | link_to: "/" }}', {});
    expect(out, '<a href="/">Home</a>');
  });

  test("link_to escapes html", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ "<b>X</b>" | link_to: "/?a=1&b=2" }}',
      {},
    );
    expect(out, '<a href="/?a=1&amp;b=2">&lt;b&gt;X&lt;/b&gt;</a>');
  });

  test("link_to title attribute", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ "X" | link_to: "/", "t" }}',
      {},
    );
    expect(out, '<a href="/" title="t">X</a>');
  });
}
