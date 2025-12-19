import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

class ProductDrop implements LiquidDrop {
  final String title;
  final int priceCents;

  ProductDrop(this.title, this.priceCents);

  @override
  Object? get(String key) {
    switch (key) {
      case "title":
        return title;
      case "price_cents":
        return priceCents;
      default:
        return null;
    }
  }
}

void main() {
  test("can access LiquidDrop properties", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{{ product.title }} {{ product.price_cents }}",
      {"product": ProductDrop("Hat", 1234)},
    );
    expect(out, "Hat 1234");
  });

  test("can disable drops", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(allowDrops: false),
    );
    final out = await engine.parseAndRender(
      "{{ product.title | default: 'X' }}",
      {"product": ProductDrop("Hat", 1234)},
    );
    expect(out, "X");
  });
}
