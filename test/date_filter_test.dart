import "package:liquid_dart/liquid_dart.dart";
import "package:test/test.dart";

void main() {
  test("date formats ISO input with offset minutes", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ "1990-12-31T23:00:00Z" | date: "%Y-%m-%dT%H:%M:%S", 360 }}',
      {},
    );
    expect(out, "1990-12-31T17:00:00");
  });

  test("date supports %q ordinal", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      "{{ '2023/02/02' | date: '%d%q of %b' }}",
      {},
    );
    expect(out, "02nd of Feb");
  });

  test("date uses options.dateFormat when format omitted", () async {
    final engine = LiquidEngine(
      options: const LiquidOptions(dateFormat: "%Y-%m-%d", timezoneOffset: 0),
    );
    final out = await engine.parseAndRender(
      '{{ "1990-12-31T23:00:00Z" | date }}',
      {},
    );
    expect(out, "1990-12-31");
  });

  test("date parses numeric seconds and milliseconds", () async {
    final engine = LiquidEngine();
    final out1 = await engine.parseAndRender('{{ 0 | date: "%Y" , 0 }}', {});
    expect(out1, "1970");

    final out2 = await engine.parseAndRender('{{ 1000 | date: "%Y", 0 }}', {});
    expect(out2, "1970"); // 1000 seconds
  });

  test("date accepts offset string for %Z", () async {
    final engine = LiquidEngine();
    final out = await engine.parseAndRender(
      '{{ "1990-12-31T23:00:00Z" | date: "%Z %z", "+0530" }}',
      {},
    );
    expect(out, "+0530 +0530");
  });
}
