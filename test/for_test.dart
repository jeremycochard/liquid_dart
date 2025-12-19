import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("for renders items", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs %}{{ x }}{% endfor %}",
      {
        "xs": [1, 2, 3],
      },
    );
    expect(out, "123");
  });

  test("for else branch when empty", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs %}A{% else %}B{% endfor %}",
      {"xs": []},
    );
    expect(out, "B");
  });

  test("for limit and offset", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs offset:1 limit:2 %}{{ x }}{% endfor %}",
      {
        "xs": [1, 2, 3, 4],
      },
    );
    expect(out, "23");
  });

  test("for reversed", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs reversed %}{{ x }}{% endfor %}",
      {
        "xs": [1, 2, 3],
      },
    );
    expect(out, "321");
  });

  test("break stops loop", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs %}{{ x }}{% if x == 3 %}{% break %}{% endif %}{% endfor %}",
      {
        "xs": [1, 2, 3, 4],
      },
    );
    expect(out, "123");
  });

  test("continue skips iteration", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs %}{% if x == 2 %}{% continue %}{% endif %}{{ x }}{% endfor %}",
      {
        "xs": [1, 2, 3, 4],
      },
    );
    expect(out, "134");
  });

  test("forloop metadata", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for x in xs %}{{ forloop.index }}{% endfor %}",
      {
        "xs": ["a", "b", "c"],
      },
    );
    expect(out, "123");
  });

  test("assign persists across loop", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{% assign s = "" %}{% for x in xs %}{% assign s = s | append: x %}{% endfor %}{{ s }}',
      {
        "xs": ["a", "b", "c"],
      },
    );
    expect(out, "abc");
  });

  test("break outside for throws", () async {
    final engine = LiquidEngine();
    expect(
      () => engine.parseAndRender("{% break %}", {}),
      throwsA(isA<LiquidRenderError>()),
    );
  });
}
