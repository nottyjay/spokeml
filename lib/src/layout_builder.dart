import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import '../spoke_ml.dart';
import 'constructor_validator.dart';

Builder spokeMlBuilder(BuilderOptions _) => const SpokeMlLayoutBuilder();

final class SpokeMlLayoutBuilder implements Builder {
  const SpokeMlLayoutBuilder();

  static const inputPrefix = 'layouts/';
  static const outputPrefix = 'lib/generated/';

  @override
  Map<String, List<String>> get buildExtensions => const {
    '^layouts/{{}}.xml': [
      'lib/generated/{{}}.g.dart',
      'lib/generated/{{}}.g.dart.spoke.json',
    ],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final relativePath = input.path.substring(
      inputPrefix.length,
      input.path.length - '.xml'.length,
    );
    final output = AssetId(input.package, '$outputPrefix$relativePath.g.dart');
    final mapOutput = AssetId(
      input.package,
      '$outputPrefix$relativePath.g.dart.spoke.json',
    );
    final source = await buildStep.readAsString(input);
    final compiler = SpokeMlCompiler();
    final parsed = compiler.parse(source, sourcePath: input.path);
    final document = await _resolveIncludes(parsed, buildStep);
    await const ConstructorValidator().validate(document, buildStep.resolver);
    final generated = compiler.generate(document, sourceMarkers: true);
    final formatted = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(generated);
    final mapped = const SpokeMlSourceMapWriter().write(
      formatted,
      _sourceLocations(document),
    );
    await buildStep.writeAsString(output, mapped.source);
    await buildStep.writeAsString(mapOutput, mapped.mapJson);
  }

  Future<LayoutDocument> _resolveIncludes(
    LayoutDocument document,
    BuildStep buildStep,
  ) async {
    final includes = <String, ResolvedInclude>{};
    for (final node in _walk(document.root)) {
      if (node.namespacePrefix != null || node.name != 'Include') continue;
      final layout = node.attributes['layout'];
      if (layout is! LiteralValue) {
        throw SpokeMlCompileException(
          '<Include> requires a literal "layout" path.',
          location: layout?.location ?? node.location,
        );
      }
      if (includes.containsKey(layout.source)) continue;
      final targetPath = Uri(
        path: buildStep.inputId.path,
      ).resolve(layout.source).path;
      if (!targetPath.startsWith(inputPrefix) || !targetPath.endsWith('.xml')) {
        throw SpokeMlCompileException(
          'Include path "${layout.source}" must resolve inside layouts/.',
          location: layout.location,
        );
      }
      final target = AssetId(buildStep.inputId.package, targetPath);
      if (!await buildStep.canRead(target)) {
        throw SpokeMlCompileException(
          'Included layout "$targetPath" does not exist.',
          location: layout.location,
        );
      }
      final targetSource = await buildStep.readAsString(target);
      final targetDocument = SpokeMlCompiler().parse(
        targetSource,
        sourcePath: targetPath,
      );
      final generatedPath = targetPath.substring(
        inputPrefix.length,
        targetPath.length - '.xml'.length,
      );
      includes[layout.source] = ResolvedInclude(
        layoutPath: targetPath,
        className: targetDocument.className,
        importUri: 'package:${target.package}/generated/$generatedPath.g.dart',
        variables: targetDocument.variables
            .map((variable) => variable.name)
            .toSet(),
      );
    }
    return LayoutDocument(
      className: document.className,
      sourcePath: document.sourcePath,
      imports: document.imports,
      variables: document.variables,
      root: document.root,
      includes: Map.unmodifiable(includes),
    );
  }

  Iterable<WidgetNode> _walk(WidgetNode root) sync* {
    yield root;
    for (final child in root.children) {
      yield* _walk(child);
    }
  }

  Iterable<SourceLocation> _sourceLocations(LayoutDocument document) sync* {
    for (final variable in document.variables) {
      if (variable.create case final create?) {
        yield create.valueLocation;
      }
    }
    for (final node in _walk(document.root)) {
      yield node.location;
      for (final value in node.attributes.values) {
        yield value.valueLocation;
      }
    }
  }
}
