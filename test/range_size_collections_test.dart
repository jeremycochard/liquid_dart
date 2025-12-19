import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("range in for loop", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% for i in (1..3) %}{{ i }}{% endfor %}",
      {},
    );
    expect(out, "123");
  });

  test("range can be assigned and iterated", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{% assign r = (2..4) %}{% for i in r %}{{ i }}{% endfor %}",
      {},
    );
    expect(out, "234");
  });

  test("range output concatenates like liquid", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender("{{ (1..5) }}", {});
    expect(out, "12345");
  });

  test("size property and filter", () async {
    final engine = LiquidEngine();
    final out1 = await engine.parseAndRender(
      "{% assign s = 'abcd' %}{{ s.size }}",
      {},
    );
    expect(out1, "4");

    final out2 = await engine.parseAndRender("{{ 'abcd' | size }}", {});
    expect(out2, "4");

    final out3 = await engine.parseAndRender(
      "{% assign a = (1..3) %}{{ a.size }}",
      {},
    );
    expect(out3, "3");
  });

  test("map where sort", () async {
    final engine = LiquidEngine();
    final data = {
      "products": [
        {"title": "B", "available": true, "rank": 2},
        {"title": "A", "available": false, "rank": 1},
        {"title": "C", "available": true, "rank": 3},
      ],
    };

    final out1 = await engine.parseAndRender(
      "{{ products | map: 'title' | join: ',' }}",
      data,
    );
    expect(out1, "B,A,C");

    final out2 = await engine.parseAndRender(
      "{{ products | where: 'available', true | map: 'title' | join: ',' }}",
      data,
    );
    expect(out2, "B,C");

    final out3 = await engine.parseAndRender(
      "{{ products | sort: 'rank' | map: 'title' | join: ',' }}",
      data,
    );
    expect(out3, "A,B,C");
  });
}
