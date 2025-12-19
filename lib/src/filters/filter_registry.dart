typedef LiquidFilter = Object? Function(Object? input, List<Object?> args);

class FilterRegistry {
  final Map<String, LiquidFilter> _filters = {};

  void register(String name, LiquidFilter fn) {
    _filters[name] = fn;
  }

  LiquidFilter? lookup(String name) => _filters[name];
}
