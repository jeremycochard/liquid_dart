import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("renders plain text unchanged", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("hello", {});
    expect(out, "hello");
  });

  test("renders empty string", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("", {});
    expect(out, "");
  });
}
