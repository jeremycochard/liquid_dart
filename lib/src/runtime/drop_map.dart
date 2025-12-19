import "liquid_drop.dart";

class DropMap implements LiquidDrop {
  final Map map;
  DropMap(this.map);

  @override
  Object? get(String key) => map[key];
}
