import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';

import 'model.dart';

/// Validates constructor names and named arguments against resolved Dart APIs.
final class ConstructorValidator {
  const ConstructorValidator();

  Future<void> validate(LayoutDocument document, Resolver resolver) async {
    await _validateNode(document.root, document, resolver);
  }

  Future<void> _validateNode(
    WidgetNode node,
    LayoutDocument document,
    Resolver resolver,
  ) async {
    final importUri = switch ((node.namespacePrefix, node.name.contains('.'))) {
      (final prefix?, _) => document.imports[prefix]!,
      (null, true) => 'package:flutter/material.dart',
      _ => null,
    };
    if (importUri != null) {
      await _validateConstructor(node, importUri, resolver);
    }
    for (final child in node.children) {
      await _validateNode(child, document, resolver);
    }
  }

  Future<void> _validateConstructor(
    WidgetNode node,
    String importUri,
    Resolver resolver,
  ) async {
    final uri = Uri.parse(importUri);
    final segments = uri.pathSegments;
    final library = await resolver.libraryFor(
      AssetId(segments.first, 'lib/${segments.skip(1).join('/')}'),
    );
    final nameParts = node.name.split('.');
    final typeName = nameParts.first;
    final constructorName = nameParts.length == 1 ? 'new' : nameParts[1];
    final type = library.exportNamespace.get2(typeName);
    if (type is! InterfaceElement) {
      throw SpokeMlCompileException(
        'The library "$importUri" does not export a widget type "$typeName".',
        location: node.location,
      );
    }
    final constructor = type.getNamedConstructor(constructorName);
    if (constructor == null) {
      throw SpokeMlCompileException(
        'Type "$typeName" does not define constructor "$constructorName".',
        location: node.location,
      );
    }

    final parameters = {
      for (final parameter in constructor.formalParameters)
        if (parameter.isNamed) parameter.name!: parameter,
    };
    final positionalParameters = constructor.formalParameters
        .where((parameter) => parameter.isPositional)
        .toList();
    final positionalEntries = node.attributes.entries
        .where((entry) => RegExp(r'^arg\d+$').hasMatch(entry.key))
        .toList()
      ..sort(
        (left, right) => int.parse(
          left.key.substring(3),
        ).compareTo(int.parse(right.key.substring(3))),
      );
    for (var index = 0; index < positionalEntries.length; index++) {
      final actualIndex = int.parse(positionalEntries[index].key.substring(3));
      if (actualIndex != index) {
        throw SpokeMlCompileException(
          '<${node.name}> positional arguments must be contiguous from '
          '"arg0"; found "${positionalEntries[index].key}".',
          location: positionalEntries[index].value.location,
        );
      }
    }
    final requiredPositionalCount = positionalParameters
        .where((parameter) => parameter.isRequiredPositional)
        .length;
    if (positionalEntries.length < requiredPositionalCount ||
        positionalEntries.length > positionalParameters.length) {
      throw SpokeMlCompileException(
        '<${node.name}> supplies ${positionalEntries.length} positional '
        'arguments, but constructor "$constructorName" expects between '
        '$requiredPositionalCount and ${positionalParameters.length}.',
        location: node.location,
      );
    }
    final supplied = <String, SourceLocation>{
      for (final entry in node.attributes.entries)
        if (!const {'visible', 'if', 'key'}.contains(entry.key) &&
            !RegExp(r'^arg\d+$').hasMatch(entry.key))
          entry.key: entry.value.location,
    };
    final builderChildren = node.children
        .where(
          (child) => child.namespacePrefix == null && child.name == 'Builder',
        )
        .toList();
    final slotChildren = node.children
        .where(
          (child) => child.namespacePrefix == null && child.name == 'Slot',
        )
        .toList();
    for (final slot in slotChildren) {
      final name = slot.attributes['name'];
      if (name case LiteralValue(:final source, :final location)) {
        if (supplied.containsKey(source)) {
          throw SpokeMlCompileException(
            '<Slot name="$source"> duplicates another constructor argument.',
            location: location,
          );
        }
        supplied[source] = location;
        final parameter = parameters[source];
        if (parameter != null && parameter.type is FunctionType) {
          throw SpokeMlCompileException(
            '<Slot name="$source"> cannot target a callback parameter; '
            'use <Builder> instead.',
            location: location,
          );
        }
      }
    }
    for (final builder in builderChildren) {
      final name = builder.attributes['name'];
      if (name case LiteralValue(:final source, :final location)) {
        supplied[source] = location;
        final parameter = parameters[source];
        final callback = parameter?.type;
        if (parameter != null && callback is! FunctionType) {
          throw SpokeMlCompileException(
            '<Builder name="$source"> targets a non-callback parameter.',
            location: location,
          );
        }
        if (callback is FunctionType) {
          _validateBuilderArguments(builder, source, callback);
        }
      }
    }
    final widgetChildCount =
        node.children.length - builderChildren.length - slotChildren.length;
    final containsCollection = node.children.any(
      (child) => child.namespacePrefix == null && child.name == 'ForEach',
    );
    if (widgetChildCount == 1 && !containsCollection) {
      supplied['child'] = node.children
          .firstWhere(
            (child) =>
                !builderChildren.contains(child) &&
                !slotChildren.contains(child),
          )
          .location;
    } else if (widgetChildCount > 0) {
      supplied['children'] = node.location;
    }

    for (final entry in supplied.entries) {
      if (!parameters.containsKey(entry.key)) {
        throw SpokeMlCompileException(
          '<${node.name}> constructor does not define named parameter '
          '"${entry.key}".',
          location: entry.value,
        );
      }
    }
    for (final parameter in parameters.values.where(
      (parameter) => parameter.isRequiredNamed,
    )) {
      if (!supplied.containsKey(parameter.name)) {
        throw SpokeMlCompileException(
          '<${node.name}> requires named parameter "${parameter.name}".',
          location: node.location,
        );
      }
    }
  }

  void _validateBuilderArguments(
    WidgetNode builder,
    String parameterName,
    FunctionType callback,
  ) {
    final arguments = switch (builder.attributes['args']) {
      LiteralValue(:final source) =>
        source
            .split(',')
            .map((argument) => argument.trim())
            .where((argument) => argument.isNotEmpty)
            .length,
      _ => 0,
    };
    final positional = callback.formalParameters
        .where((parameter) => parameter.isPositional)
        .toList();
    final required = positional
        .where((parameter) => !parameter.isOptional)
        .length;
    if (arguments < required || arguments > positional.length) {
      throw SpokeMlCompileException(
        '<Builder name="$parameterName"> declares $arguments callback '
        'arguments, but the constructor expects between $required and '
        '${positional.length}.',
        location: builder.attributes['args']?.location ?? builder.location,
      );
    }
  }
}
