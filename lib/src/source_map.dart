import 'dart:convert';

import 'model.dart';

/// Maps generated Dart diagnostics back to XML source ranges.
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
            (left, right) =>
                left.generatedStart.compareTo(right.generatedStart),
          );
    return SpokeMlSourceMap._(entries);
  }

  final List<_SourceMapEntry> _entries;

  /// Looks up a one-based line for version 1 line-only source maps.
  SourceLocation? lookup(int generatedLine) {
    _SourceMapEntry? match;
    for (final entry in _entries) {
      if (entry.generatedLine > generatedLine) break;
      match = entry;
    }
    return match?.source;
  }

  /// Looks up a zero-based offset.
  SourceLocation? lookupOffset(int generatedOffset) {
    for (final entry in _entries) {
      if (entry.contains(generatedOffset)) return entry.source;
    }
    return null;
  }

  /// Converts a one-based Dart line and column to an XML source location.
  SourceLocation? lookupPosition(
    String generatedSource,
    int generatedLine,
    int generatedColumn,
  ) {
    final offset = _offsetForPosition(
      generatedSource,
      generatedLine,
      generatedColumn,
    );
    return lookupOffset(offset) ?? lookup(generatedLine);
  }
}

/// Finds temporary mapping markers in formatted Dart and builds a sidecar.
final class SpokeMlSourceMapWriter {
  const SpokeMlSourceMapWriter();

  static final _marker = RegExp(r'/\* spoke_ml:(\d+):(\d+) \*/');

  SpokeMlMappedSource write(
    String markedSource,
    Iterable<SourceLocation> locations,
  ) {
    final locationByKey = {
      for (final location in locations) _key(location): location,
    };
    final markers = _marker.allMatches(markedSource).toList();
    final lineStarts = _lineStarts(markedSource);
    final entries = <_SourceMapEntry>[];

    for (var index = 0; index < markers.length; index++) {
      final marker = markers[index];
      final key = '${marker.group(1)}:${marker.group(2)}';
      final source = locationByKey[key];
      if (source == null) continue;
      entries.add(
        _SourceMapEntry(
          generatedStart: marker.end,
          generatedEnd: index + 1 < markers.length
              ? markers[index + 1].start
              : markedSource.length,
          generatedLine: _lineForOffset(lineStarts, marker.end),
          source: source,
        ),
      );
    }

    return SpokeMlMappedSource(
      source: markedSource,
      mapJson: const JsonEncoder.withIndent('  ').convert({
        'version': 2,
        'entries': entries.map((entry) => entry.toJson()).toList(),
      }),
    );
  }

  String _key(SourceLocation location) =>
      '${location.offset}:${location.length}';
}

final class SpokeMlMappedSource {
  const SpokeMlMappedSource({required this.source, required this.mapJson});

  final String source;
  final String mapJson;
}

final class _SourceMapEntry {
  const _SourceMapEntry({
    required this.generatedStart,
    required this.generatedEnd,
    required this.generatedLine,
    required this.source,
  });

  factory _SourceMapEntry.fromJson(Map<String, Object?> json) {
    final generatedLine = json['generatedLine']! as int;
    final generatedStart = json['generatedStart'] as int?;
    final generatedEnd = json['generatedEnd'] as int?;
    return _SourceMapEntry(
      generatedStart: generatedStart ?? -1,
      generatedEnd: generatedEnd ?? -1,
      generatedLine: generatedLine,
      source: SourceLocation(
        path: json['path']! as String,
        offset: json['offset']! as int,
        line: json['line']! as int,
        column: json['column']! as int,
        length: json['length'] as int? ?? 0,
      ),
    );
  }

  final int generatedStart;
  final int generatedEnd;
  final int generatedLine;
  final SourceLocation source;

  bool contains(int offset) =>
      generatedStart >= 0 && offset >= generatedStart && offset < generatedEnd;

  Map<String, Object> toJson() => {
    'generatedStart': generatedStart,
    'generatedEnd': generatedEnd,
    'generatedLine': generatedLine,
    'path': source.path,
    'offset': source.offset,
    'line': source.line,
    'column': source.column,
    'length': source.length,
  };
}

int _offsetForPosition(String source, int line, int column) {
  final starts = _lineStarts(source);
  if (line < 1 || line > starts.length) return 0;
  return (starts[line - 1] + column - 1).clamp(0, source.length);
}

List<int> _lineStarts(String source) {
  final starts = <int>[0];
  for (var index = 0; index < source.length; index++) {
    if (source.codeUnitAt(index) == 10) starts.add(index + 1);
  }
  return starts;
}

int _lineForOffset(List<int> starts, int offset) {
  var lower = 0;
  var upper = starts.length;
  while (lower < upper) {
    final middle = lower + ((upper - lower) >> 1);
    if (starts[middle] <= offset) {
      lower = middle + 1;
    } else {
      upper = middle;
    }
  }
  return lower;
}
