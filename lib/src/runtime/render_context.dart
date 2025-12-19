import "../engine/liquid_options.dart";
import "../filters/filter_registry.dart";
import "block_store.dart";
import "render_limits.dart";

class RenderContext {
  final Map<String, Object?> globals;
  final LiquidOptions options;
  final FilterRegistry filters;

  final Future<void> Function(String name, StringBuffer out, RenderContext ctx)
  renderPartial;

  final List<Map<String, Object?>> _scopes;

  final Map<String, int> _cycles = {};

  final Map<String, int> _increments;
  final Map<String, int> _decrements;

  final BlockStore blocks;

  final RenderLimits limits;

  RenderContext({
    required this.globals,
    required this.options,
    required this.filters,
    required this.renderPartial,
    BlockStore? blocks,
    Map<String, int>? sharedIncrements,
    Map<String, int>? sharedDecrements,
    RenderLimits? limits,
  }) : _scopes = [<String, Object?>{}],
       blocks = blocks ?? BlockStore(),
       _increments = sharedIncrements ?? <String, int>{},
       _decrements = sharedDecrements ?? <String, int>{},
       limits =
           limits ??
           RenderLimits(
             maxDepth: 50,
             maxSteps: 200000,
             maxOutputSize: 5 * 1024 * 1024,
           );

  RenderContext forkForRender() {
    return RenderContext(
      globals: globals,
      options: options,
      filters: filters,
      renderPartial: renderPartial,
      sharedIncrements: _increments,
      sharedDecrements: _decrements,
      limits: limits,
    );
  }

  int nextCycleIndex(String group, int count) {
    final cur = _cycles[group] ?? 0;
    _cycles[group] = (cur + 1) % (count <= 0 ? 1 : count);
    return cur;
  }

  void pushScope([Map<String, Object?>? scope]) {
    _scopes.add(scope ?? <String, Object?>{});
  }

  void popScope() {
    if (_scopes.length == 1) {
      throw StateError("Cannot pop root scope");
    }
    _scopes.removeLast();
  }

  Object? lookup(String name) {
    for (var i = _scopes.length - 1; i >= 0; i--) {
      final scope = _scopes[i];
      if (scope.containsKey(name)) return scope[name];
    }
    return globals[name];
  }

  void set(String name, Object? value) {
    _scopes.first[name] = value;
  }

  void setLocal(String name, Object? value) {
    _scopes.last[name] = value;
  }

  int increment(String name) {
    final v = _increments[name] ?? 0;
    _increments[name] = v + 1;
    return v;
  }

  int decrement(String name) {
    final v = (_decrements[name] ?? 0) - 1;
    _decrements[name] = v;
    return v;
  }
}
