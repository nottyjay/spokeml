import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';

import '../spoke_ml.dart';

Builder spokeMlBuilder(BuilderOptions _) => const SpokeMlLayoutBuilder();

final class SpokeMlLayoutBuilder implements Builder {
  const SpokeMlLayoutBuilder();

  static const inputPrefix = 'layouts/';
  static const outputPrefix = 'lib/generated/';

  @override
  Map<String, List<String>> get buildExtensions => const {
    '^layouts/{{}}.xml': ['lib/generated/{{}}.g.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;
    final relativePath = input.path.substring(
      inputPrefix.length,
      input.path.length - '.xml'.length,
    );
    final output = AssetId(input.package, '$outputPrefix$relativePath.g.dart');
    final source = await buildStep.readAsString(input);
    final generated = SpokeMlCompiler().compile(source, sourcePath: input.path);
    final formatted = DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format(generated);
    await buildStep.writeAsString(output, formatted);
  }
}
