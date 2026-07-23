import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:spoke_ml/spoke_ml.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.firstOrNull == 'analyze') {
    await _analyze(arguments.skip(1).toList(growable: false));
    return;
  }
  _compile(arguments);
}

void _compile(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln(
      'Usage:\n'
      '  dart run spoke_ml <layout.xml> [output.dart]\n'
      '  dart run spoke_ml analyze [path]',
    );
    exitCode = 64;
    return;
  }

  try {
    final source = File(arguments.first).readAsStringSync();
    final output = SpokeMlCompiler().compile(
      source,
      sourcePath: arguments.first,
    );
    if (arguments.length == 2) {
      File(arguments[1]).writeAsStringSync(output);
    } else {
      stdout.write(output);
    }
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 66;
  } on SpokeMlCompileException catch (error) {
    stderr.writeln(error);
    exitCode = 65;
  }
}

Future<void> _analyze(List<String> arguments) async {
  if (arguments.length > 1) {
    stderr.writeln('Usage: dart run spoke_ml analyze [path]');
    exitCode = 64;
    return;
  }

  final process = await Process.start(Platform.resolvedExecutable, [
    'analyze',
    '--format=machine',
    if (arguments.isNotEmpty) arguments.single,
  ]);
  final diagnostics = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  final stderrDone = stderr.addStream(process.stderr);
  await for (final diagnostic in diagnostics) {
    stdout.writeln(_remapDiagnostic(diagnostic));
  }
  await stderrDone;
  exitCode = await process.exitCode;
}

String _remapDiagnostic(String diagnostic) {
  final fields = diagnostic.split('|');
  if (fields.length < 8) return diagnostic;

  final generatedPath = fields[3];
  final mapFile = File('$generatedPath.spoke.json');
  final generatedFile = File(generatedPath);
  if (!mapFile.existsSync() || !generatedFile.existsSync()) {
    return diagnostic;
  }

  try {
    final generatedLine = int.parse(fields[4]);
    final generatedColumn = int.parse(fields[5]);
    final sourceMap = SpokeMlSourceMap.fromJson(mapFile.readAsStringSync());
    final location = sourceMap.lookupPosition(
      generatedFile.readAsStringSync(),
      generatedLine,
      generatedColumn,
    );
    if (location == null) return diagnostic;

    final message = fields.sublist(7).join('|');
    final length = location.length == 0
        ? fields[6]
        : location.length.toString();
    return [
      fields[0],
      fields[1],
      fields[2],
      location.path,
      location.line,
      location.column,
      length,
      message,
    ].join('|');
  } on FileSystemException {
    return diagnostic;
  } on FormatException {
    return diagnostic;
  }
}
