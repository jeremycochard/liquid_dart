import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

class CountingFileSystem implements LiquidFileSystem {
  final Map<String, String> templates;
  int reads = 0;

  CountingFileSystem(this.templates);

  @override
  Future<String> readTemplate(String name) async {
    reads++;
    final v = templates[name];
    if (v == null) throw LiquidRenderError("Template not found: $name");
    return v;
  }
}

void main() {
  test("include can see parent assigns", () async {
    final fs = InMemoryFileSystem({"p": "{{ x }}"});

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.parseAndRender(
      '{% assign x = "A" %}{% include "p" %}',
      {},
    );
    expect(out, "A");
  });

  test("render is isolated from parent assigns", () async {
    final fs = InMemoryFileSystem({"p": "{{ x | default: 'Z' }}"});

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.parseAndRender(
      '{% assign x = "A" %}{% render "p" %}',
      {},
    );
    expect(out, "Z");
  });

  test("render receives named args", () async {
    final fs = InMemoryFileSystem({"p": "{{ x }}"});

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.parseAndRender(
      '{% assign x = "A" %}{% render "p", x: x %}',
      {},
    );
    expect(out, "A");
  });

  test("include receives named args", () async {
    final fs = InMemoryFileSystem({"p": "{{ v }}"});

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.parseAndRender('{% include "p", v: "X" %}', {});
    expect(out, "X");
  });

  test("renderFile loads template by name", () async {
    final fs = InMemoryFileSystem({"main": "Hi {{ name }}"});

    final engine = LiquidEngine(fileSystem: fs);
    final out = await engine.renderFile("main", {"name": "Ada"});
    expect(out, "Hi Ada");
  });

  test("template cache avoids repeated reads when enabled", () async {
    final fs = CountingFileSystem({"p": "X"});

    final engine = LiquidEngine(fileSystem: fs);
    expect(await engine.renderFile("p", {}), "X");
    expect(await engine.renderFile("p", {}), "X");
    expect(fs.reads, 1);
  });

  test("disabling cache reads each time", () async {
    final fs = CountingFileSystem({"p": "X"});

    final engine = LiquidEngine(
      fileSystem: fs,
      options: const LiquidOptions(cacheTemplates: false),
    );

    expect(await engine.renderFile("p", {}), "X");
    expect(await engine.renderFile("p", {}), "X");
    expect(fs.reads, 2);
  });
}
