/// Resolves asset keys to full URLs.
typedef AssetUrlResolver = String Function(String key);

/// Resolves file keys to full URLs.
typedef FileUrlResolver = String Function(String key);

/// Resolves image keys and requested sizes to full URLs.
typedef ImageUrlResolver = String Function(String key, String size);

/// Configuration for parsing and rendering Liquid templates.
class LiquidOptions {
  /// Whether missing variables cause render errors.
  final bool strictVariables;

  /// Whether unknown filters cause render errors.
  final bool strictFilters;

  /// Whether parsed templates are cached by name.
  final bool cacheTemplates;

  /// Default date format for the `date` filter.
  final String dateFormat;

  /// JS-style minutes offset: 360 => -06:00, -330 => +05:30
  /// Or string like "+0530" or "Europe/Paris" (zone name used for %Z).
  /// Timezone offset or zone name used when formatting dates.
  final Object? timezoneOffset;

  /// Format string used by the `money` filter.
  final String moneyFormat;

  /// Optional resolver for `asset_url`.
  final AssetUrlResolver? assetUrlResolver;

  /// Optional resolver for `file_url`.
  final FileUrlResolver? fileUrlResolver;

  /// Optional resolver for `img_url`.
  final ImageUrlResolver? imageUrlResolver;

  /// Maximum include/layout depth during rendering.
  final int maxRenderDepth;

  /// Maximum render steps before aborting.
  final int maxRenderSteps;

  /// Maximum output size in bytes.
  final int maxOutputSize;

  /// Whether `LiquidDrop` values are allowed.
  final bool allowDrops;

  /// Creates a new set of Liquid engine options.
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
