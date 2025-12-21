import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("forloop.parentloop is available in nested loops", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for a in (1..2) %}{% for b in (1..2) %}[{{ forloop.parentloop.index }}-{{ forloop.index }}]{% endfor %}{% endfor %}",
      {},
    );
    expect(out, "[1-1][1-2][2-1][2-2]");
  });
}
