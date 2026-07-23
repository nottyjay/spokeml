import 'generator.dart';
import 'model.dart';
import 'parser.dart';

/// Compiles a SpokeML XML document into a Flutter widget source file.
final class SpokeMlCompiler {
  SpokeMlCompiler({LayoutParser? parser, FlutterWidgetGenerator? generator})
    : _parser = parser ?? LayoutParser(),
      _generator = generator ?? FlutterWidgetGenerator();

  final LayoutParser _parser;
  final FlutterWidgetGenerator _generator;

  LayoutDocument parse(String source, {String sourcePath = '<memory>'}) =>
      _parser.parse(source, sourcePath: sourcePath);

  String generate(LayoutDocument document, {bool sourceMarkers = false}) =>
      _generator.generate(document, sourceMarkers: sourceMarkers);

  String compile(String source, {String sourcePath = '<memory>'}) =>
      generate(parse(source, sourcePath: sourcePath));
}
