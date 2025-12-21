import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("reject", () async {
    final engine = LiquidEngine();
    final data = {
      "xs": [
        {"a": true, "t": "A"},
        {"a": false, "t": "B"},
        {"a": true, "t": "C"},
      ],
    };

    final out = await engine.parseAndRender(
      "{{ xs | reject: 'a' | map: 't' | join: ',' }}",
      data,
    );
    expect(out, "B");
  });

  test("reject_exp", () async {
    final engine = LiquidEngine();
    final data = {
      "xs": [
        {"n": 1},
        {"n": 2},
        {"n": 3},
      ],
    };

    final out = await engine.parseAndRender(
      "{{ xs | reject_exp: 'x', 'x.n > 1' | map: 'n' | join: ',' }}",
      data,
    );
    expect(out, "1");
  });

  test("group_by", () async {
    final engine = LiquidEngine();
    final data = {
      "xs": [
        {"k": "a", "v": 1},
        {"k": "b", "v": 2},
        {"k": "a", "v": 3},
      ],
    };

    final out = await engine.parseAndRender(
      "{% for g in xs | group_by: 'k' %}{{ g.name }}:{{ g.items.size }};{% endfor %}",
      data,
    );
    expect(out, "a:2;b:1;");
  });

  test("uniq with prop is stable", () async {
    final engine = LiquidEngine();
    final data = {
      "xs": [
        {"id": 1, "t": "A"},
        {"id": 1, "t": "B"},
        {"id": 2, "t": "C"},
      ],
    };

    final out = await engine.parseAndRender(
      "{{ xs | uniq: 'id' | map: 't' | join: ',' }}",
      data,
    );
    expect(out, "A,C");
  });
}
