import "../ast/node.dart";

class BlockStore {
  final Map<String, List<Node>> _blocks = {};

  void define(String name, List<Node> body) {
    _blocks[name] = body;
  }

  List<Node>? lookup(String name) => _blocks[name];

  bool get isEmpty => _blocks.isEmpty;
}
