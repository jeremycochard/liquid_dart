/// Zero-argument callable used by drops for computed values.
typedef LiquidCallable0 = Object? Function();

/// Interface for custom objects exposed to Liquid templates.
abstract class LiquidDrop {
  /// Returns a value for the provided [key].
  Object? get(String key);
}
