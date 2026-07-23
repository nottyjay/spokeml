import 'dart:io';

import 'package:spoke_ml/spoke_ml.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty || arguments.length > 2) {
    stderr.writeln('Usage: dart run spoke_ml <layout.xml> [output.dart]');
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
