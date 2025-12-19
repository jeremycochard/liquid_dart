import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("renders simple variable", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("hi {{ name }}", {"name": "Ada"});
    expect(out, "hi Ada");
  });

  test("renders nested variable with dot", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("user={{ user.name }}", {
      "user": {"name": "Lin"},
    });
    expect(out, "user=Lin");
  });

  test("renders bracket access", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{{ user['name'] }}", {
      "user": {"name": "Sam"},
    });
    expect(out, "Sam");
  });

  test("missing variable is empty by default", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("x={{ missing }}", {});
    expect(out, "x=");
  });

  test("missing variable throws when strictVariables is true", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(strictVariables: true),
    );
    expect(
      () => engine.parseAndRender("{{ missing }}", {}),
      throwsA(isA<LiquidRenderError>()),
    );
  });
}
