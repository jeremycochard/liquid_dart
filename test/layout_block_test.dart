import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("layout renders child blocks into parent", () async {
    final fs = InMemoryFileSystem({
      "base": "Header|{% block content %}DEFAULT{% endblock %}|Footer",
      "child":
          '{% layout "base" %}{% block content %}Hello {{ name }}{% endblock %}',
    });

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.renderFile("child", {"name": "Ada"});
    expect(out, "Header|Hello Ada|Footer");
  });

  test("layout fallback block is used when child does not define it", () async {
    final fs = InMemoryFileSystem({
      "base": "X{% block content %}DEFAULT{% endblock %}Y",
      "child": '{% layout "base" %}no blocks here',
    });

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.renderFile("child", {});
    expect(out, "XDEFAULTY");
  });

  test("child can define multiple blocks", () async {
    final fs = InMemoryFileSystem({
      "base": "{% block a %}A0{% endblock %}|{% block b %}B0{% endblock %}",
      "child":
          '{% layout "base" %}{% block b %}B1{% endblock %}{% block a %}A1{% endblock %}',
    });

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.renderFile("child", {});
    expect(out, "A1|B1");
  });
}
