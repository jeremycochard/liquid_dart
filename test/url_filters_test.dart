import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("asset_url uses resolver when provided", () async {
    final engine = LiquidEngine(
      options: LiquidOptions(
        assetUrlResolver: (k) => "https://cdn.test/assets/$k",
      ),
    );

    final out = await engine.parseAndRender(
      '{{ "theme.css" | asset_url }}',
      {},
    );
    expect(out, "https://cdn.test/assets/theme.css");
  });

  test("file_url uses resolver when provided", () async {
    final engine = LiquidEngine(
      options: LiquidOptions(
        fileUrlResolver: (k) => "https://cdn.test/files/$k",
      ),
    );

    final out = await engine.parseAndRender(
      '{{ "manual.pdf" | file_url }}',
      {},
    );
    expect(out, "https://cdn.test/files/manual.pdf");
  });

  test("img_url default adds suffix before extension", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ "products/p.jpg" | img_url: "200x200" }}',
      {},
    );
    expect(out, "products/p_200x200.jpg");
  });

  test("img_url keeps query string", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ "p.jpg?v=1" | img_url: "100x" }}',
      {},
    );
    expect(out, "p_100x.jpg?v=1");
  });

  test("img_url resolver overrides default behavior", () async {
    final engine = LiquidEngine(
      options: LiquidOptions(
        imageUrlResolver: (k, size) => "https://img.test/$size/$k",
      ),
    );

    final out = await engine.parseAndRender(
      '{{ "p.jpg" | img_url: "100x" }}',
      {},
    );
    expect(out, "https://img.test/100x/p.jpg");
  });
}
