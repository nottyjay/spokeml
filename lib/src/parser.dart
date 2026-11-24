import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

import 'model.dart';

final class LayoutParser {
  LayoutDocument parse(String source, {String sourcePath = '<memory>'}) {
    return _LayoutParseContext(source: source, sourcePath: sourcePath).parse();
  }
}

final class _LayoutParseContext {
  _LayoutParseContext({required this.source, required this.sourcePath});

  static final _identifier = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  static final _binding = RegExp(r'^@\{(.+)\}$', dotAll: true);
  static final _typeExpression = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_?.]*(?:\s*<[\sA-Za-z0-9_?.,<>\[\]]+>)?\??$',
  );
  // dart:core is implicitly imported in generated Dart. Keep this explicit:
  // capitalization alone must not exempt undeclared binding roots.
  static const _dartCoreTypes = {
    'ArgumentError',
    'AssertionError',
    'BigInt',
    'bool',
    'Comparable',
    'Comparator',
    'ConcurrentModificationError',
    'DateTime',
    'Deprecated',
    'double',
    'Duration',
    'dynamic',
    'Enum',
    'Error',
    'Exception',
    'Expando',
    'Finalizer',
    'FormatException',
    'Function',
    'Future',
    'IndexError',
    'int',
    'IntegerDivisionByZeroException',
    'Invocation',
    'Iterable',
    'Iterator',
    'List',
    'Map',
    'MapEntry',
    'Match',
    'Never',
    'NoSuchMethodError',
    'Null',
    'num',
    'Object',
    'OutOfMemoryError',
    'ParallelWaitError',
    'Pattern',
    'pragma',
    'RangeError',
    'Record',
    'RegExp',
    'RegExpMatch',
    'RuneIterator',
    'Runes',
    'Set',
    'Sink',
    'StackOverflowError',
    'StackTrace',
    'StateError',
    'Stopwatch',
    'Stream',
    'String',
    'StringBuffer',
    'StringSink',
    'Symbol',
    'Type',
    'TypeError',
    'UnimplementedError',
    'UnsupportedError',
    'Uri',
    'UriData',
    'WeakReference',
  };
  static const _dartKeywords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'base',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'covariant',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'Function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'of',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'sealed',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'when',
    'while',
    'with',
    'yield',
  };

  final String source;
  final String sourcePath;
  final Map<XmlElement, _ElementLocation> _locations = HashMap.identity();
  late final List<int> _lineStarts = _computeLineStarts();

  LayoutDocument parse() {
    final XmlDocument xml;
    try {
      xml = XmlDocument.parse(source);
    } on XmlParserException catch (error) {
      throw SpokeMlCompileException(
        'Invalid XML: ${error.message}',
        location: _locationAt(error.position ?? 0),
      );
    }
    _indexLocations(xml);

    final layout = xml.rootElement;
    if (layout.localName != 'layout') {
      throw _error('The document root must be <layout>.', _locationOf(layout));
    }
    _validateLayoutAttributes(layout);

    final className = layout.getAttribute('class') ?? 'GeneratedLayout';
    _requireIdentifier(
      className,
      'layout class',
      _attributeLocation(layout, 'class'),
    );
    final imports = _parseImports(layout);

    final elements = layout.childElements.toList(growable: false);
    final dataElements = elements
        .where((element) => element.localName == 'data')
        .toList();
    if (dataElements.length > 1) {
      throw _error(
        '<layout> may contain at most one <data> element.',
        _locationOf(dataElements[1]),
      );
    }

    final variables = dataElements.isEmpty
        ? const <LayoutVariable>[]
        : _parseVariables(dataElements.single);
    final widgetElements = elements
        .where((element) => element.localName != 'data')
        .toList();
    if (widgetElements.length != 1) {
      throw _error(
        '<layout> must contain exactly one root widget.',
        _locationOf(layout),
      );
    }

    final root = _parseWidget(widgetElements.single);
    _validateNamespaces(root, imports.keys.toSet());
    _validateBindings(root, {
      ..._dartCoreTypes,
      'context',
      'Key',
      'ObjectKey',
      'UniqueKey',
      'ValueKey',
      ...imports.keys,
      ...variables.map((variable) => variable.name),
    });
    return LayoutDocument(
      className: className,
      sourcePath: sourcePath,
      imports: imports,
      variables: variables,
      root: root,
    );
  }

  void _indexLocations(XmlDocument document) {
    final elements = <XmlElement>[
      document.rootElement,
      ...document.rootElement.descendants.whereType<XmlElement>(),
    ];
    final events = parseEvents(
      source,
      withLocation: true,
      validateDocument: true,
      validateNesting: true,
    ).whereType<XmlStartElementEvent>().toList();
    for (
      var index = 0;
      index < elements.length && index < events.length;
      index++
    ) {
      _locations[elements[index]] = _ElementLocation(
        start: events[index].start ?? 0,
        stop: events[index].stop ?? events[index].start ?? 0,
      );
    }
  }

  void _validateLayoutAttributes(XmlElement layout) {
    for (final attribute in layout.attributes) {
      if (attribute.localName == 'class' || attribute.name.prefix == 'xmlns') {
        continue;
      }
      throw _error(
        '<layout> does not support attribute "${attribute.name}".',
        _attributeLocation(layout, attribute.name.toString()),
      );
    }
  }

  Map<String, String> _parseImports(XmlElement layout) {
    final imports = <String, String>{};
    for (final attribute in layout.attributes) {
      if (attribute.name.prefix != 'xmlns') {
        continue;
      }
      final prefix = attribute.localName;
      final location = _attributeLocation(layout, attribute.name.toString());
      _requireIdentifier(prefix, 'namespace prefix', location);
      final uri = attribute.value;
      if (!_isPackageUri(uri)) {
        throw _error(
          'Namespace "$prefix" must reference a valid package: URI.',
          location,
        );
      }
      imports[prefix] = uri;
    }
    return Map.unmodifiable(imports);
  }

  List<LayoutVariable> _parseVariables(XmlElement data) {
    if (data.attributes.isNotEmpty) {
      final attribute = data.attributes.first;
      throw _error(
        '<data> does not support attribute "${attribute.name}".',
        _attributeLocation(data, attribute.name.toString()),
      );
    }

    final result = <LayoutVariable>[];
    final names = <String>{};
    for (final element in data.childElements) {
      if (element.localName != 'variable') {
        throw _error(
          '<data> only supports <variable>, found <${element.localName}>.',
          _locationOf(element),
        );
      }
      for (final attribute in element.attributes) {
        if (!const {
          'name',
          'type',
          'import',
          'ownership',
          'create',
          'dispose',
        }.contains(attribute.localName)) {
          throw _error(
            '<variable> does not support attribute "${attribute.name}".',
            _attributeLocation(element, attribute.name.toString()),
          );
        }
      }

      final location = _locationOf(element);
      final name = element.getAttribute('name');
      if (name == null) {
        throw _error('<variable> requires a name attribute.', location);
      }
      _requireIdentifier(
        name,
        'variable name',
        _attributeLocation(element, 'name'),
      );
      if (!names.add(name)) {
        throw _error('Duplicate variable "$name".', location);
      }

      final type = element.getAttribute('type') ?? 'dynamic';
      if (!_typeExpression.hasMatch(type)) {
        throw _error(
          'Invalid Dart type "$type".',
          _attributeLocation(element, 'type'),
        );
      }
      final import = element.getAttribute('import');
      if (import != null && !_isPackageUri(import)) {
        throw _error(
          'Variable "$name" import must be a valid package: URI.',
          _attributeLocation(element, 'import'),
        );
      }
      final ownershipSource =
          element.getAttribute('ownership') ?? VariableOwnership.external.name;
      final ownership = VariableOwnership.values
          .where((value) => value.name == ownershipSource)
          .firstOrNull;
      if (ownership == null) {
        throw _error(
          'Variable "$name" ownership must be "external" or "owned".',
          _attributeLocation(element, 'ownership'),
        );
      }
      final createSource = element.getAttribute('create');
      final create = createSource == null
          ? null
          : _parseValue(
              createSource,
              _attributeLocation(element, 'create'),
              _attributeValueLocation(element, 'create'),
            );
      if (ownership == VariableOwnership.owned && create is! BindingValue) {
        throw _error(
          'Owned variable "$name" requires create="@{...}".',
          create?.location ?? _locationOf(element),
        );
      }
      if (ownership == VariableOwnership.external && create != null) {
        throw _error(
          'External variable "$name" cannot declare create.',
          create.location,
        );
      }
      final dispose = element.getAttribute('dispose');
      if (dispose != null &&
          dispose != 'none' &&
          !_identifier.hasMatch(dispose)) {
        throw _error(
          'Variable "$name" dispose must be "none" or a method name.',
          _attributeLocation(element, 'dispose'),
        );
      }
      result.add(
        LayoutVariable(
          name: name,
          type: type,
          import: import,
          ownership: ownership,
          create: create as BindingValue?,
          dispose: dispose,
          location: location,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  WidgetNode _parseWidget(XmlElement element) {
    for (final node in element.children.whereType<XmlText>()) {
      if (node.value.trim().isNotEmpty) {
        throw _error(
          '<${element.localName}> cannot contain raw text; use an attribute.',
          _locationOf(element),
        );
      }
    }

    return WidgetNode(
      name: element.localName,
      namespacePrefix: element.name.prefix,
      attributes: Map.unmodifiable({
        for (final attribute in element.attributes)
          attribute.localName: _parseValue(
            attribute.value,
            _attributeLocation(element, attribute.name.toString()),
            _attributeValueLocation(element, attribute.name.toString()),
          ),
      }),
      children: List.unmodifiable(
        element.childElements.map(_parseWidget).toList(),
      ),
      location: _locationOf(element),
    );
  }

  void _validateNamespaces(WidgetNode node, Set<String> imports) {
    final prefix = node.namespacePrefix;
    if (prefix != null && !imports.contains(prefix)) {
      throw _error(
        '<$prefix:${node.name}> uses undeclared namespace "$prefix".',
        node.location,
      );
    }
    for (final child in node.children) {
      _validateNamespaces(child, imports);
    }
  }

  LayoutValue _parseValue(
    String valueSource,
    SourceLocation location, [
    SourceLocation? valueLocation,
  ]) {
    final match = _binding.firstMatch(valueSource.trim());
    if (match == null) {
      return LiteralValue(valueSource, location, valueLocation: valueLocation);
    }
    final expression = match.group(1)!.trim();
    if (expression.isEmpty) {
      throw _error('A binding expression cannot be empty.', location);
    }
    final rawValue = valueLocation == null
        ? valueSource
        : source.substring(
            valueLocation.offset,
            valueLocation.offset + valueLocation.length,
          );
    final rawExpression =
        _binding.firstMatch(rawValue.trim())?.group(1) ?? expression;
    final trimmedRawExpression = rawExpression.trim();
    final bindingStart = rawValue.indexOf('@{');
    final innerStart = rawValue.indexOf(trimmedRawExpression, bindingStart + 2);
    final expressionLocation = valueLocation == null
        ? location
        : _locationAt(
            valueLocation.offset + innerStart,
            length: trimmedRawExpression.length,
          );
    return BindingValue(
      expression,
      location,
      valueLocation: expressionLocation,
    );
  }

  void _validateBindings(WidgetNode node, Set<String> roots) {
    final isForEach = node.namespacePrefix == null && node.name == 'ForEach';
    for (final entry in node.attributes.entries) {
      if (isForEach && entry.key == 'keyBy') continue;
      if (entry.value case final BindingValue value) {
        _validateBinding(value, roots);
      }
    }

    final childRoots = {...roots};
    if (node.namespacePrefix == null) {
      switch (node.name) {
        case 'Observe':
          _addScopedIdentifier(
            node,
            childRoots,
            'as',
            'Observe alias',
            required: false,
          );
          break;
        case 'ForEach':
          _addScopedIdentifier(node, childRoots, 'as', 'ForEach item alias');
          _addScopedIdentifier(
            node,
            childRoots,
            'index',
            'ForEach index alias',
            required: false,
          );
          if (node.attributes['keyBy'] case final BindingValue keyBy) {
            _validateBinding(keyBy, childRoots);
          }
          break;
        case 'Builder':
          final args = node.attributes['args'];
          if (args case LiteralValue(:final source, :final location)) {
            for (final argument in source.split(',')) {
              final name = argument.trim();
              _requireIdentifier(name, 'Builder argument', location);
              childRoots.add(name);
            }
          }
          break;
        case 'Slot':
          _addScopedIdentifier(node, childRoots, 'name', 'Slot name');
          break;
      }
    }
    for (final child in node.children) {
      _validateBindings(child, childRoots);
    }
  }

  void _validateBinding(BindingValue value, Set<String> roots) {
    final expression = value.source.trim();
    final parsed = parseString(
      content: 'final _value = ($expression);',
      throwIfDiagnostics: false,
    );
    if (parsed.errors.isNotEmpty) {
      throw _error(
        'Invalid binding "@{${value.source}}": ${parsed.errors.first.message}',
        value.location,
      );
    }
    final declaration =
        parsed.unit.declarations.single as TopLevelVariableDeclaration;
    final initializer = declaration.variables.variables.single.initializer!;
    final identifiers = <String>[];
    for (
      var token = initializer.beginToken;
      token != initializer.endToken.next;
      token = token.next!
    ) {
      // Dart tokens exclude string contents and comments, while preserving
      // identifiers inside string interpolation. Member names aren't roots.
      if ((token.isIdentifier || _dartCoreTypes.contains(token.lexeme)) &&
          token.previous?.lexeme != '.' &&
          token.previous?.lexeme != '?.') {
        identifiers.add(token.lexeme);
      }
    }
    final localRoots = <String>{};
    for (final match in RegExp(
      r'\(([^)]*)\)\s*(?:async\s*)?=>',
    ).allMatches(value.source)) {
      for (final parameter in match.group(1)!.split(',')) {
        final identifiers = RegExp(
          r'[A-Za-z_][A-Za-z0-9_]*',
        ).allMatches(parameter).toList();
        if (identifiers.isNotEmpty) {
          localRoots.add(identifiers.last.group(0)!);
        }
      }
    }
    final singleParameter = RegExp(
      r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:async\s*)?=>',
    ).firstMatch(value.source);
    if (singleParameter != null) {
      localRoots.add(singleParameter.group(1)!);
    }

    final rootIdentifier = identifiers
        .where(
          (identifier) =>
              !_dartKeywords.contains(identifier) ||
              _dartCoreTypes.contains(identifier),
        )
        .firstOrNull;
    if (rootIdentifier != null &&
        !roots.contains(rootIdentifier) &&
        !localRoots.contains(rootIdentifier)) {
      throw _error(
        'Binding "@{${value.source}}" references undeclared variable '
        '"$rootIdentifier".',
        value.location,
      );
    }
  }

  void _addScopedIdentifier(
    WidgetNode node,
    Set<String> roots,
    String attribute,
    String label, {
    bool required = true,
  }) {
    final value = node.attributes[attribute];
    if (value == null && !required) return;
    if (value case LiteralValue(:final source, :final location)) {
      _requireIdentifier(source, label, location);
      roots.add(source);
      return;
    }
    if (value != null || required) {
      throw _error(
        '<${node.name}> requires a literal "$attribute" identifier.',
        value?.location ?? node.location,
      );
    }
  }

  void _requireIdentifier(String value, String label, SourceLocation location) {
    if (!_identifier.hasMatch(value) || _dartKeywords.contains(value)) {
      throw _error(
        'Invalid $label "$value"; expected a non-keyword Dart identifier.',
        location,
      );
    }
  }

  bool _isPackageUri(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'package' &&
        uri.pathSegments.length >= 2 &&
        !value.contains("'") &&
        !value.contains('\n') &&
        !value.contains('\r');
  }

  SourceLocation _locationOf(XmlElement element) {
    return _locationAt(_locations[element]?.start ?? 0);
  }

  SourceLocation _attributeLocation(XmlElement element, String name) {
    final elementLocation = _locations[element];
    if (elementLocation == null) {
      return _locationOf(element);
    }
    final openingTag = source.substring(
      elementLocation.start,
      elementLocation.stop.clamp(elementLocation.start, source.length),
    );
    final match = RegExp(
      '(?:^|\\s)${RegExp.escape(name)}\\s*=',
    ).firstMatch(openingTag);
    if (match == null) {
      return _locationOf(element);
    }
    final leadingWhitespace =
        openingTag.codeUnitAt(match.start) == 32 ||
            openingTag.codeUnitAt(match.start) == 9 ||
            openingTag.codeUnitAt(match.start) == 10 ||
            openingTag.codeUnitAt(match.start) == 13
        ? 1
        : 0;
    return _locationAt(elementLocation.start + match.start + leadingWhitespace);
  }

  SourceLocation _attributeValueLocation(XmlElement element, String name) {
    final elementLocation = _locations[element];
    if (elementLocation == null) {
      return _locationOf(element);
    }
    final openingTag = source.substring(
      elementLocation.start,
      elementLocation.stop.clamp(elementLocation.start, source.length),
    );
    final match = RegExp(
      '(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*(["\'])',
    ).firstMatch(openingTag);
    if (match == null) {
      return _attributeLocation(element, name);
    }
    final quote = match.group(1)!;
    final valueStart = match.end;
    final valueEnd = openingTag.indexOf(quote, valueStart);
    final length = valueEnd < 0 ? 0 : valueEnd - valueStart;
    return _locationAt(elementLocation.start + valueStart, length: length);
  }

  SourceLocation _locationAt(int offset, {int length = 0}) {
    var lower = 0;
    var upper = _lineStarts.length;
    while (lower < upper) {
      final middle = lower + ((upper - lower) >> 1);
      if (_lineStarts[middle] <= offset) {
        lower = middle + 1;
      } else {
        upper = middle;
      }
    }
    final lineIndex = lower - 1;
    return SourceLocation(
      path: sourcePath,
      offset: offset,
      line: lineIndex + 1,
      column: offset - _lineStarts[lineIndex] + 1,
      length: length,
    );
  }

  List<int> _computeLineStarts() {
    final starts = <int>[0];
    for (var index = 0; index < source.length; index++) {
      if (source.codeUnitAt(index) == 10) {
        starts.add(index + 1);
      }
    }
    return starts;
  }

  SpokeMlCompileException _error(String message, SourceLocation location) {
    return SpokeMlCompileException(message, location: location);
  }
}

final class _ElementLocation {
  const _ElementLocation({required this.start, required this.stop});

  final int start;
  final int stop;
}
