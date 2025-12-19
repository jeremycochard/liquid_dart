import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("concat", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ a | concat: b | join: "," }}', {
      "a": [1, 2],
      "b": [3],
    });
    expect(out, "1,2,3");
  });

  test("sort_natural", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ xs | sort_natural | join: "," }}',
      {
        "xs": ["b", "A", "c"],
      },
    );
    expect(out, "A,b,c");
  });

  test("dig", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender('{{ obj | dig: "a", "b", 1 }}', {
      "obj": {
        "a": {
          "b": ["x", "y"],
        },
      },
    });
    expect(out, "y");
  });

  test("where_exp", () async {
    final engine = LiquidEngine();
    final data = {
      "products": [
        {"title": "A", "rank": 1, "available": true},
        {"title": "B", "rank": 2, "available": false},
        {"title": "C", "rank": 3, "available": true},
      ],
    };

    final out = await engine.parseAndRender(
      "{{ products | where_exp: 'p', 'p.rank > 1 and p.available == true' | map: 'title' | join: ',' }}",
      data,
    );

    expect(out, "C");
  });
}
