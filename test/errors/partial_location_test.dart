import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("include missing template carries caller location", () async {
    final engine = LiquidEngine(fileSystem: InMemoryFileSystem({}));
    expect(
      () => engine.parseAndRender("A{% include 'nope' %}B", {}),
      throwsA(
        predicate(
          (e) =>
              e is LiquidRenderError &&
              e.location != null &&
              e.location!.col == 2,
        ),
      ),
    );
  });

  test("layout missing template carries caller location", () async {
    final fs = InMemoryFileSystem({
      "child": "{% layout 'missing' %}{% block content %}X{% endblock %}",
    });
    final engine = LiquidEngine(fileSystem: fs);

    expect(
      () => engine.renderFile("child", {}),
      throwsA(predicate((e) => e is LiquidRenderError && e.location != null)),
    );
  });
}
