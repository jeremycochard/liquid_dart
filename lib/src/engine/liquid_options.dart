typedef AssetUrlResolver = String Function(String key);
typedef FileUrlResolver = String Function(String key);
typedef ImageUrlResolver = String Function(String key, String size);

class LiquidOptions {
  final bool strictVariables;
  final bool strictFilters;
  final bool cacheTemplates;

  final String dateFormat;

  /// JS-style minutes offset: 360 => -06:00, -330 => +05:30
  /// Or string like "+0530" or "Europe/Paris" (zone name used for %Z).
  final Object? timezoneOffset;

  final String moneyFormat;

  final AssetUrlResolver? assetUrlResolver;
  final FileUrlResolver? fileUrlResolver;
  final ImageUrlResolver? imageUrlResolver;

  final int maxRenderDepth;
  final int maxRenderSteps;
  final int maxOutputSize;

  final bool allowDrops;

  const LiquidOptions({
    this.strictVariables = false,
    this.strictFilters = false,
    this.cacheTemplates = true,
    this.dateFormat = "%A, %B %-e, %Y at %-l:%M %P %z",
    this.timezoneOffset,
    this.moneyFormat = r"${{amount}}",
    this.assetUrlResolver,
    this.fileUrlResolver,
    this.imageUrlResolver,
    this.maxRenderDepth = 50,
    this.maxRenderSteps = 200000,
    this.maxOutputSize = 5 * 1024 * 1024,
    this.allowDrops = true,
  });
}
