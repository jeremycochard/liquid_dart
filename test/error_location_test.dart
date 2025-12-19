import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("parse error carries token location", () {
    final engine = LiquidEngine();
    expect(
      () => engine.parse("{% no_such_tag %}"),
      throwsA(
        predicate((e) {
          return e is LiquidParseError &&
              e.location != null &&
              e.location!.line == 1 &&
              e.location!.col == 1;
        }),
      ),
    );
  });

  test("render error carries output location in strictVariables", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(strictVariables: true),
    );
    expect(
      () => engine.parseAndRender("X {{ missing }}", {}),
      throwsA(
        predicate((e) {
          return e is LiquidRenderError &&
              e.location != null &&
              e.location!.line == 1 &&
              e.location!.col == 3;
        }),
      ),
    );
  });

  test("unknown filter carries location", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(strictFilters: true),
    );
    expect(
      () => engine.parseAndRender("A{{ x | no_such_filter }}B", {"x": "1"}),
      throwsA(
        predicate((e) {
          return e is LiquidRenderError &&
              e.location != null &&
              e.location!.line == 1 &&
              e.location!.col == 2;
        }),
      ),
    );
  });
}
