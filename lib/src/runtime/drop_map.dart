import "liquid_drop.dart";

/// Adapts a Dart [Map] into a [LiquidDrop].
class DropMap implements LiquidDrop {
  /// Backing map for key lookup.
  final Map map;

  /// Creates a drop backed by [map].
  DropMap(this.map);

  @override
  /// Returns the value for [key] from the backing map.
  Object? get(String key) => map[key];
}
