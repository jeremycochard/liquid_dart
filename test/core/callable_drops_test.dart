import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

class UserDrop implements LiquidDrop {
  final String first;
  final String last;

  UserDrop(this.first, this.last);

  @override
  Object? get(String key) {
    switch (key) {
      case "first":
        return first;
      case "last":
        return last;
      case "full_name":
        return () => "$first $last";
      default:
        return null;
    }
  }
}

void main() {
  test("drop callable is invoked", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{{ u.full_name }}", {
      "u": UserDrop("Ada", "Lovelace"),
    });
    expect(out, "Ada Lovelace");
  });
}
