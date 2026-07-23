import 'dart:convert';

import 'model.dart';

/// Maps a generated Dart diagnostic line back to the nearest XML widget.
final class SpokeMlSourceMap {
  SpokeMlSourceMap._(this._entries);

  factory SpokeMlSourceMap.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, Object?>;
    final entries =
        (json['entries']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(_SourceMapEntry.fromJson)
            .toList()
          ..sort(
            (left, right) => left.generatedLine.compareTo(right.generatedLine),
          );
    return SpokeMlSourceMap._(entries);
  }

  final List<_SourceMapEntry> _entries;

  SourceLocation? lookup(int generatedLine) {
    _SourceMapEntry? match;
    for (final entry in _entries) {
      if (entry.generatedLine > generatedLine) break;
      match = entry;
    }
    return match?.source;
  }
}

final class _SourceMapEntry {
  const _SourceMapEntry({required this.generatedLine, required this.source});

  factory _SourceMapEntry.fromJson(Map<String, Object?> json) {
    return _SourceMapEntry(
      generatedLine: json['generatedLine']! as int,
      source: SourceLocation(
        path: json['path']! as String,
        offset: json['offset']! as int,
        line: json['line']! as int,
        column: json['column']! as int,
      ),
    );
  }

  final int generatedLine;
  final SourceLocation source;
}
