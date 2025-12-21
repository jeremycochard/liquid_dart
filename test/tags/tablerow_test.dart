import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("tablerow renders table rows and cols", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% tablerow x in xs cols:2 %}{{ x }}{% endtablerow %}",
      {
        "xs": [1, 2, 3],
      },
    );
    expect(
      out,
      '<tr class="row1"><td class="col1">1</td><td class="col2">2</td></tr><tr class="row2"><td class="col1">3</td></tr>',
    );
  });

  test("tablerow supports offset and limit", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% tablerow x in xs cols:2 offset:1 limit:2 %}{{ x }}{% endtablerow %}",
      {
        "xs": [1, 2, 3, 4],
      },
    );
    expect(
      out,
      '<tr class="row1"><td class="col1">2</td><td class="col2">3</td></tr>',
    );
  });
}
