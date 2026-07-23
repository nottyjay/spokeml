/// A parsed SpokeML layout document.
final class LayoutDocument {
  const LayoutDocument({
    required this.className,
    required this.sourcePath,
    required this.imports,
    required this.variables,
    required this.root,
  });

  final String className;
  final String sourcePath;
  final Map<String, String> imports;
  final List<LayoutVariable> variables;
  final WidgetNode root;
}

/// A value made available to binding expressions in a layout.
final class LayoutVariable {
  const LayoutVariable({
    required this.name,
    required this.type,
    required this.import,
    required this.location,
  });

  final String name;
  final String type;
  final String? import;
  final SourceLocation location;
}

/// A widget and its attributes and descendants.
final class WidgetNode {
  const WidgetNode({
    required this.name,
    required this.namespacePrefix,
    required this.attributes,
    required this.children,
    required this.location,
  });

  final String name;
  final String? namespacePrefix;
  final Map<String, LayoutValue> attributes;
  final List<WidgetNode> children;
  final SourceLocation location;
}

sealed class LayoutValue {
  const LayoutValue(this.location);

  String get source;
  final SourceLocation location;
}

/// A constant value written directly in XML.
final class LiteralValue extends LayoutValue {
  const LiteralValue(this.source, super.location);

  @override
  final String source;
}

/// A Dart expression written as `@{expression}`.
final class BindingValue extends LayoutValue {
  const BindingValue(this.source, super.location);

  @override
  final String source;
}

/// A source position in a SpokeML document.
final class SourceLocation {
  const SourceLocation({
    required this.path,
    required this.offset,
    required this.line,
    required this.column,
  });

  final String path;
  final int offset;
  final int line;
  final int column;

  @override
  String toString() => '$path:$line:$column';
}

/// A compile-time error in a SpokeML document.
final class SpokeMlCompileException implements Exception {
  const SpokeMlCompileException(this.message, {this.location});

  final String message;
  final SourceLocation? location;

  @override
  String toString() {
    final prefix = location;
    return prefix == null ? message : '$prefix: $message';
  }
}
