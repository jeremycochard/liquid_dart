import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("liquid tag supports assign and echo", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% liquid assign x = 1; echo x %}",
      {},
    );
    expect(out, "1");
  });

  test("liquid tag supports multiline if", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% liquid\nassign x = 2\nif x == 2\necho 'ok'\nendif\n%}",
      {},
    );
    expect(out, "ok");
  });

  test("liquid tag supports for and break", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% liquid\nfor x in (1..5)\necho x\nif x == 3\nbreak\nendif\nendfor\n%}",
      {},
    );
    expect(out, "123");
  });
}
