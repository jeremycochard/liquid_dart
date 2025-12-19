import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("maxRenderSteps stops huge loops", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(maxRenderSteps: 10),
    );

    expect(
      () => engine.parseAndRender(
        "{% for i in (1..100) %}{{ i }}{% endfor %}",
        {},
      ),
      throwsA(isA<LiquidRenderError>()),
    );
  });

  test("maxRenderDepth stops recursive include", () async {
    final fs = InMemoryFileSystem({"a": "{% include 'a' %}"});

    final engine = LiquidEngine(
      fileSystem: fs,
      options: const LiquidOptions(maxRenderDepth: 5),
    );

    expect(() => engine.renderFile("a", {}), throwsA(isA<LiquidRenderError>()));
  });
}
