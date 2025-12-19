````md
# liquid_dart

Moteur de templates Liquid pour Dart et Flutter.

Ce projet est un portage 1:1 (objectif de compatibilité comportementale) de **LiquidJS 10.24.0** vers Dart, et a été construit comme une **expérimentation itérative avec GPT-5.2** (développement guidé par tests, corrections successives, focus sur la compatibilité).

## Statut

- Version actuelle: `0.1.0` (recommandé: publier d’abord en `0.x` tant que l’API et la compatibilité Shopify ne sont pas figées)
- Plateformes: Dart VM, Flutter (iOS, Android, web, desktop)
- Null safety: oui
- Rendu: async (chargement de templates via filesystem asynchrone)

## Installation

Avec pub:

```bash
dart pub add liquid_dart
````

Ou dans `pubspec.yaml`:

```yaml
dependencies:
  liquid_dart: ^0.1.0
```

## Exemple rapide

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

## Chargement de templates: include, render, layout

### FileSystem (include/render/layout depuis des fichiers)

`liquid_dart` ne lit pas le disque directement. Tu fournis un `LiquidFileSystem`.

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

* `{% include "partial" %}` partage le scope du parent.
* `{% render "partial" %}` exécute dans un scope isolé, mais accepte des paramètres nommés.

```liquid
{% assign x = "A" %}
{% include "p" %}
{% render "p" %}
```

Paramètres nommés:

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

### Résolveurs Shopify URL

```dart
final engine = LiquidEngine(
  options: LiquidOptions(
    assetUrlResolver: (k) => "https://cdn.example/assets/$k",
    fileUrlResolver: (k) => "https://cdn.example/files/$k",
    imageUrlResolver: (k, size) => "https://img.example/$size/$k",
  ),
);
```

## Drops (objets Dart)

`liquid_dart` supporte les objets via une interface explicite, sans reflection.

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
        return () => "Product: $title"; // callable 0-arg
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

Désactivation:

```dart
final engine = LiquidEngine(options: const LiquidOptions(allowDrops: false));
```

## Erreurs: location + snippet

Les erreurs peuvent inclure:

* position `ligne:col`
* la ligne concernée
* un caret `^` pointant la zone

Exemples:

* parse: tag inconnu
* render: variable manquante (en strict)
* render: filtre inconnu (en strict)
* include/render/layout: template manquant (avec position du tag appelant)

## Fonctionnalités supportées

### Tags

Supportés:

* `assign`
* `capture ... endcapture`
* `if / elsif / else / endif`
* `for / else / endfor`
* `break`, `continue`
* `cycle`
* `tablerow ... endtablerow`
* `include`
* `render`
* `layout`
* `block ... endblock`
* `raw ... endraw`
* `comment ... endcomment`
* `liquid` (multi-lignes, `echo`, statements séparés par newline ou `;`)

Variables de boucle:

* `forloop.index`, `forloop.index0`, `forloop.rindex`, `forloop.rindex0`, `forloop.first`, `forloop.last`, `forloop.length`
* `forloop.parentloop`
* `tablerowloop.index`, `tablerowloop.row`, `tablerowloop.col`, `tablerowloop.length`

Whitespace control:

* `{{- ... -}}`
* `{%- ... -%}`

### Expressions

Supportés:

* littéraux: string, number, bool, nil
* chemins: `a.b.c`
* comparaisons: `== != > >= < <=`
* booléens: `and`, `or`, `not`
* ranges: `(1..n)`
* filtres via pipe: `{{ x | upcase | append: "!" }}`

### Filtres

Texte:

* `upcase`, `downcase`, `capitalize`
* `append`, `prepend`
* `strip`, `lstrip`, `rstrip`, `strip_newlines`
* `replace`, `replace_first`, `remove`, `remove_first`
* `split`, `join`
* `slice` (string)
* `truncate`, `truncatewords`
* `escape`, `strip_html`, `newline_to_br`
* `handleize`
* `link_to`
* `url_encode`, `url_escape`

Numériques:

* `plus`, `minus`, `times`, `divided_by`, `modulo`
* `abs`, `floor`, `ceil`, `round`

Collections:

* `size` (filtre) et `.size` (propriété)
* `first`, `last`, `reverse`, `compact`
* `map`
* `where`, `reject`
* `where_exp`, `reject_exp`
* `sort`, `sort_natural`
* `uniq` (option `uniq: 'prop'`, stable)
* `concat`
* `dig`

Divers:

* `default`
* `json`
* `date`
* `money`
* `asset_url`, `shopify_asset_url`, `file_url`, `img_url`

## Limitations connues

Compatibilité LiquidJS / Shopify:

* Shopify Liquid est très large. Cette librairie couvre un socle très utilisable, mais pas l’intégralité du runtime Shopify.
* `where_exp` et `reject_exp` sont un sous-ensemble limité.
* `date` vise la compatibilité pratique. La gestion des timezones nommées sans base TZ n’est pas complète.
* `img_url` par défaut applique un suffixe simple avant extension. Pour un comportement CDN, utiliser `imageUrlResolver`.

Performance et sécurité:

* Les filtres sont synchrones.
* Limites de rendu: profondeur, steps, taille de sortie.
* Cache templates: activé par défaut si `cacheTemplates: true`.

API:

* En `0.x`, l’API publique peut évoluer.

## Roadmap (suggestion)

* Tags Shopify fréquents: `paginate`, `case/when`
* Compat include avancé: `include ... for`, `include ... with`
* Filtres Shopify additionnels: `t`, `money_with_currency`, etc
* Benchmarks et optimisations

## Contribuer

PRs bienvenues.
Recommandé:

* Ajout de fonctionnalités via tests d’abord
* Approche compat: tester les comportements attendus (LiquidJS / Shopify)