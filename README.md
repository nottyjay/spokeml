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

Each generated Dart file also has a `.g.dart.spoke.json` sidecar. It maps
generated Dart ranges to their XML widget, attribute, or binding-expression
range through `SpokeMlSourceMap`.

Run analysis through SpokeML to report downstream Dart type errors at their XML
locations:

```sh
dart run spoke_ml analyze
```

For example, an invalid `itemCount="@{controller}"` binding is reported as:

```text
ERROR|COMPILE_TIME_ERROR|ARGUMENT_TYPE_NOT_ASSIGNABLE|
layouts/catalog/product_list.xml|10|36|10|...
```

The analyzer's exit code is preserved, and diagnostics without a SpokeML map
are passed through unchanged. This mechanism is build-time Dart tooling, so it
works the same way for Android, iOS, macOS, Windows, Linux, and web targets.

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
Streams use the same local boundary and expose an `AsyncSnapshot`:

```xml
<Observe stream="@{controller.events}" as="snapshot">
  <Text text="@{snapshot.data.toString()}" />
</Observe>
```

## Dynamic collections

SpokeML does not own paging, cursors, retries, or network requests. A Dart
controller owns that policy and notifies the smallest surrounding `Observe`
when its item collection changes.

Named builder slots work with Flutter and third-party lazy widgets:

```xml
<ListView.builder itemCount="@{controller.products.length}">
  <Builder name="itemBuilder" args="context,index">
    <Text
      text="@{controller.products[index].name}"
      key="@{ValueKey(controller.products[index].id)}" />
  </Builder>
</ListView.builder>
```

For eager `children` collections, `ForEach` introduces item and index scope and
requires a stable identity:

```xml
<Column>
  <ForEach items="@{products}" as="product" index="index"
           keyBy="@{product.id}">
    <Text text="@{product.name}" />
  </ForEach>
</Column>
```

## Composition and lifecycle

Layouts can include another generated layout and forward its data:

```xml
<Include layout="./product_item.xml" product="@{product}" />
```

Variables are external by default. An explicitly owned controller generates a
thin `StatefulWidget` host while the XML renderer remains a `StatelessWidget`:

```xml
<variable
  name="controller"
  type="LoginController"
  ownership="owned"
  create="@{LoginController()}" />
```

The generated `LoginViewHost` creates and disposes the controller, then injects
it into `LoginView`. Use `dispose="none"` for an owned resource that has no
dispose method.

Use `visible` to keep a subtree alive while hiding it. Use `if` to conditionally
construct and dispose the subtree:

```xml
<Text text="Submitting" if="@{controller.isSubmitting}" />
```

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
- Stream observation through an `AsyncSnapshot` alias
- Structural `if`, generic `ForEach`, stable keys, and named builder callbacks
- Relative `Include` composition with parameter validation
- Explicit owned/external resource lifecycle
- Third-party package namespaces
- XML file, line, and column diagnostics
- Analyzer-backed constructor and named-parameter validation during generation

Still planned: complete callback and expression type validation, richer slot
schemas, IDE diagnostics directly inside XML editors, and golden tests across
Flutter versions.
