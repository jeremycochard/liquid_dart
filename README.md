# liquid_dart

Liquid template engine for Dart and Flutter.

This project is a 1:1 port (behavioral compatibility goal) of **LiquidJS 10.24.0** to Dart, and was built as an **iterative experiment with GPT-5.2** (test-driven development, successive fixes, focus on compatibility).

## Status

- Current version: `0.1.0` (recommended: publish in `0.x` first while the API and Shopify compatibility are not finalized)
- Platforms: Dart VM, Flutter (iOS, Android, web, desktop)
- Null safety: yes
- Rendering: async (template loading via an async filesystem)

## Installation

With pub:

```bash
dart pub add liquid_dart
```

Or in `pubspec.yaml`:

```yaml
dependencies:
  liquid_dart: ^0.1.0
```

## Quick example

```dart
import "package:liquid_dart/liquid_dart.dart";

Future<void> main() async {
  final engine = LiquidEngine();

  final out = await engine.parseAndRender(
    "Hello {{ name | upcase }}!",
    {"name": "Ada"},
  );

  print(out); // Hello ADA!
}
```

## Template loading: include, render, layout

### FileSystem (include/render/layout from files)

`liquid_dart` does not read the disk directly. You provide a `LiquidFileSystem`.

```dart
final fs = InMemoryFileSystem({
  "base": "Header|{% block content %}DEFAULT{% endblock %}|Footer",
  "child": "{% layout 'base' %}{% block content %}Hello {{ name }}{% endblock %}",
});

final engine = LiquidEngine(fileSystem: fs);

final out = await engine.renderFile("child", {"name": "Ada"});
// Header|Hello Ada|Footer
```

### include vs render

- `{% include "partial" %}` shares the parent scope.
- `{% render "partial" %}` runs in an isolated scope, but accepts named parameters.

```liquid
{% assign x = "A" %}
{% include "p" %}
{% render "p" %}
```

Named parameters:

```liquid
{% render "p", title: "Hello", user: user %}
```

## Options

```dart
final engine = LiquidEngine(
  options: const LiquidOptions(
    strictVariables: false,
    strictFilters: false,
    cacheTemplates: true,

    dateFormat: "%Y-%m-%d",
    timezoneOffset: 0,

    moneyFormat: r"${{amount}}",

    maxRenderDepth: 50,
    maxRenderSteps: 200000,
    maxOutputSize: 5 * 1024 * 1024,

    allowDrops: true,
  ),
);
```

### Shopify URL resolvers

```dart
final engine = LiquidEngine(
  options: LiquidOptions(
    assetUrlResolver: (k) => "https://cdn.example/assets/$k",
    fileUrlResolver: (k) => "https://cdn.example/files/$k",
    imageUrlResolver: (k, size) => "https://img.example/$size/$k",
  ),
);
```

## Drops (Dart objects)

`liquid_dart` supports objects via an explicit interface, without reflection.

```dart
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
      case "full_title":
        return () => "Product: $title"; // 0-arg callable
      default:
        return null;
    }
  }
}
```

Usage:

```dart
final out = await engine.parseAndRender(
  "{{ p.full_title }}",
  {"p": ProductDrop("Hat", 12345)},
);
```

Disabling:

```dart
final engine = LiquidEngine(options: const LiquidOptions(allowDrops: false));
```

## Errors: location + snippet

Errors can include:

- position `line:col`
- the affected line
- a caret `^` pointing to the area

Examples:

- parse: unknown tag
- render: missing variable (in strict mode)
- render: unknown filter (in strict mode)
- include/render/layout: missing template (with position of the calling tag)

## Supported features

### Tags

Supported:

- `assign`
- `capture ... endcapture`
- `if / elsif / else / endif`
- `for / else / endfor`
- `break`, `continue`
- `cycle`
- `tablerow ... endtablerow`
- `include`
- `render`
- `layout`
- `block ... endblock`
- `raw ... endraw`
- `comment ... endcomment`
- `liquid` (multi-line, `echo`, statements separated by newline or `;`)

Loop variables:

- `forloop.index`, `forloop.index0`, `forloop.rindex`, `forloop.rindex0`, `forloop.first`, `forloop.last`, `forloop.length`
- `forloop.parentloop`
- `tablerowloop.index`, `tablerowloop.row`, `tablerowloop.col`, `tablerowloop.length`

Whitespace control:

- `{{- ... -}}`
- `{%- ... -%}`

### Expressions

Supported:

- literals: string, number, bool, nil
- paths: `a.b.c`
- comparisons: `== != > >= < <=`
- booleans: `and`, `or`, `not`
- ranges: `(1..n)`
- filters via pipe: `{{ x | upcase | append: "!" }}`

### Filters

Text:

- `upcase`, `downcase`, `capitalize`
- `append`, `prepend`
- `strip`, `lstrip`, `rstrip`, `strip_newlines`
- `replace`, `replace_first`, `remove`, `remove_first`
- `split`, `join`
- `slice` (string)
- `truncate`, `truncatewords`
- `escape`, `strip_html`, `newline_to_br`
- `handleize`
- `link_to`
- `url_encode`, `url_escape`

Numeric:

- `plus`, `minus`, `times`, `divided_by`, `modulo`
- `abs`, `floor`, `ceil`, `round`

Collections:

- `size` (filter) and `.size` (property)
- `first`, `last`, `reverse`, `compact`
- `map`
- `where`, `reject`
- `where_exp`, `reject_exp`
- `sort`, `sort_natural`
- `uniq` (option `uniq: 'prop'`, stable)
- `concat`
- `dig`

Misc:

- `default`
- `json`
- `date`
- `money`
- `asset_url`, `shopify_asset_url`, `file_url`, `img_url`

## Known limitations

LiquidJS / Shopify compatibility:

- Shopify Liquid is very broad. This library covers a very usable core, but not the entire Shopify runtime.
- `where_exp` and `reject_exp` are a limited subset.
- `date` aims for practical compatibility. Handling named timezones without a TZ database is not complete.
- `img_url` defaults to applying a simple suffix before the extension. For CDN behavior, use `imageUrlResolver`.

Performance and security:

- Filters are synchronous.
- Render limits: depth, steps, output size.
- Template cache: enabled by default if `cacheTemplates: true`.

API:

- In `0.x`, the public API may change.

## Roadmap (suggestion)

- Common Shopify tags: `paginate`, `case/when`
- Advanced include compat: `include ... for`, `include ... with`
- Additional Shopify filters: `t`, `money_with_currency`, etc
- Benchmarks and optimizations

## Contributing

PRs welcome.
Recommended:

- Add features via tests first
- Compatibility approach: test expected behaviors (LiquidJS / Shopify)
