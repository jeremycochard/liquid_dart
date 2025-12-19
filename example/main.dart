import "package:liquid_dart/liquid_dart.dart";

class ProductDrop implements LiquidDrop {
  final String title;
  final int priceCents;

  ProductDrop(this.title, this.priceCents);

  @override
  Object? get(String key) {
    switch (key) {
      case "title":
        return title;
      case "price":
        return () => priceCents;
      default:
        return null;
    }
  }
}

Future<void> main() async {
  final fs = InMemoryFileSystem({
    "base": "Header|{% block content %}DEFAULT{% endblock %}|Footer",
    "child":
        "{% layout 'base' %}{% block content %}Hello {{ user }} {{ product.title }}{% endblock %}",
  });

  final engine = LiquidEngine(
    fileSystem: fs,
    options: const LiquidOptions(
      strictVariables: true,
      moneyFormat: r"€{{amount_with_comma_separator}}",
    ),
  );

  final out = await engine.renderFile("child", {
    "user": "Ada",
    "product": ProductDrop("Hat", 12345),
  });

  print(out);
}
