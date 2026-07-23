# SpokeML

SpokeML compiles XML layouts into ordinary, type-checkable Flutter widget
source. Layout paths are mirrored one-to-one:

```text
layouts/account/login.xml
→ lib/generated/account/login.g.dart
```

## Build and watch

Add `build_runner` to the consuming application's dev dependencies and include
the top-level `layouts` directory in its `build.yaml`:

```yaml
targets:
  $default:
    sources:
      - "$package$"
      - "lib/**"
      - "layouts/**"
```

Generate once:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Continuously regenerate after XML changes:

```sh
dart run build_runner watch --delete-conflicting-outputs
```

Moving, renaming, or deleting an XML input updates its declared generated
output through the Dart build system.

## Typed data

Declare the Dart type and import for each value used by bindings:

```xml
<layout class="CalendarView">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:example/calendar_controller.dart" />
  </data>

  <Text text="@{calendar.selectionLabel}" />
</layout>
```

This generates a typed field:

```dart
final CalendarController calendar;
```

Omitting `type` remains supported for early prototyping and generates
`dynamic`.

## Local observation

Static layout regions do not need to rebuild. Wrap only a dynamic subtree:

```xml
<Observe listenable="@{controller}">
  <Text text="@{controller.label}" />
</Observe>
```

For `ValueListenable<T>`, introduce a scoped value:

```xml
<Observe valueListenable="@{controller.count}" as="count">
  <Text text="@{count.toString()}" />
</Observe>
```

These generate `ListenableBuilder` and `ValueListenableBuilder` respectively.
The owner of a controller remains responsible for disposing it.

## Third-party widgets

Map an XML namespace to a Dart package:

```xml
<layout
  xmlns:table="package:table_calendar/table_calendar.dart">
  <table:TableCalendar
    firstDay="@{calendar.firstDay}"
    lastDay="@{calendar.lastDay}"
    focusedDay="@{calendar.focusedDay}" />
</layout>
```

Simple strings, booleans, and numbers are converted automatically. Complex
objects and callbacks should use binding expressions. Dart analysis of the
generated file remains the final constructor type check.

## Current scope

- Built-in widgets: `Text`, `Column`, `Row`, `Container`, `Padding`, `Center`,
  `SizedBox`, `ElevatedButton`, and `CircularProgressIndicator`
- Values: strings, numbers, booleans, enums, colors, insets, theme text styles
- Data expressions: `@{expression}`
- Conditional visibility: `visible="@{expression}"`
- Local observation: `Listenable` and `ValueListenable`
- Third-party package namespaces
- XML file, line, and column diagnostics

Still planned: analyzer-backed constructor schemas, `Include`, conditional
construction, lazy/paged lists, stable item keys, stream observation, explicit
controller ownership, IDE support, and golden tests across Flutter versions.

