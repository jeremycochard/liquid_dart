import "../errors/liquid_error.dart";

class RenderLimits {
  final int maxDepth;
  final int maxSteps;
  final int maxOutputSize;

  int _depth = 0;
  int _steps = 0;

  RenderLimits({
    required this.maxDepth,
    required this.maxSteps,
    required this.maxOutputSize,
  });

  void tick([int n = 1]) {
    _steps += n;
    if (_steps > maxSteps) {
      throw LiquidRenderError("Render exceeded max steps ($maxSteps)");
    }
  }

  void enter(String name) {
    _depth += 1;
    if (_depth > maxDepth) {
      throw LiquidRenderError(
        "Render exceeded max depth ($maxDepth) while rendering $name",
      );
    }
  }

  void exit() {
    if (_depth > 0) _depth -= 1;
  }

  void checkOutput(StringBuffer out) {
    if (out.length > maxOutputSize) {
      throw LiquidRenderError(
        "Render exceeded max output size ($maxOutputSize)",
      );
    }
  }
}
