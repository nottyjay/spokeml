# SpokeML

[简体中文](README.zh-CN.md)

SpokeML is an experimental XML-to-Flutter compiler. It lets a Flutter
application describe widget trees in XML while keeping state, business logic,
and lifecycle policy in Dart.

```text
layouts/account/login.xml
        │ build_runner
        ▼
lib/generated/account/login.g.dart
```

The generated output is ordinary, readable, type-checkable Flutter code. There
is no XML parser or dynamic widget interpreter in the released application.

Common Flutter layout widgets are first-class XML elements. This includes
`Row`, `Column`, `Stack`, `Positioned`, `Align`, `Container`, `Padding`,
`Center`, and `SizedBox`.

> **Project status:** SpokeML is currently a proof of concept, not a
> production-ready package. Its generator, source mapping, grouped layouts,
> local state boundaries, lifecycle support, and third-party widget integration
> have executable tests. The example has also been built and launched on Android
> and macOS.

## Why SpokeML?

SpokeML explores an Android Data Binding-like workflow for Flutter:

- edit only XML files under `layouts/` for declarative widget structure;
- generate `.g.dart` files automatically with `build_runner watch`;
- preserve one-to-one folders between XML inputs and generated Dart outputs;
- use typed Dart expressions instead of a runtime string-expression engine;
- rebuild only dynamic subtrees instead of making the entire page stateful;
- use Flutter or third-party widgets through XML namespaces;
- report generator and downstream Dart errors at the originating XML location.

SpokeML does not replace Flutter's state-management ecosystem. Controllers,
networking, paging, retries, validation, and domain logic remain normal Dart
code.

## Requirements

- Dart `^3.10.4`
- Flutter `>=3.38.0`
- `build_runner`

The package is currently intended to be consumed from a local checkout:

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  spoke_ml:
    path: ../SpokeML

dev_dependencies:
  build_runner: ">=2.14.1 <2.15.0"
```

Make the top-level `layouts/` directory visible to the build system:

```yaml
# build.yaml
targets:
  $default:
    sources:
      - "$package$"
      - "lib/**"
      - "layouts/**"
```

## Quick start

Create `layouts/profile.xml`:

```xml
<layout class="ProfileView">
  <data>
    <variable
      name="controller"
      type="ProfileController"
      import="package:my_app/profile_controller.dart" />
  </data>

  <Center>
    <Column mainAxisSize="min">
      <Text text="@{controller.userName}" style="headlineMedium" />
      <SizedBox height="16" />
      <ElevatedButton onPressed="@{controller.save}">
        <Text text="Save" />
      </ElevatedButton>
    </Column>
  </Center>
</layout>
```

Generate the Dart source once:

```sh
dart run build_runner build --delete-conflicting-outputs
```

During development, keep the generator running:

```sh
dart run build_runner watch --delete-conflicting-outputs
```

SpokeML creates:

```text
layouts/profile.xml
lib/generated/profile.g.dart
lib/generated/profile.g.dart.spoke.json
```

Use the generated view like any other Flutter widget:

```dart
import 'generated/profile.g.dart';

ProfileView(controller: profileController)
```

The `.spoke.json` sidecar maps generated Dart ranges back to XML. It is build
metadata and is used by SpokeML's diagnostic remapper.

## Layout organization

Input and output paths always mirror each other:

```text
layouts/profile.xml
layouts/account/login.xml
layouts/admin/login.xml

lib/generated/profile.g.dart
lib/generated/account/login.g.dart
lib/generated/admin/login.g.dart
```

This allows different feature folders to use the same XML filename without
classifying everything into one generated namespace. Each layout must still
declare a suitable Dart class name.

Moving, renaming, or deleting an XML input updates its declared output through
the Dart build system.

## Data and expressions

Declare every value that the generated view receives:

```xml
<data>
  <variable
    name="calendar"
    type="CalendarController"
    import="package:my_app/calendar_controller.dart" />
</data>
```

This produces a typed field and constructor parameter:

```dart
final CalendarController calendar;
```

Use `@{...}` for Dart expressions:

```xml
<Text
  text="@{calendar.selectionLabel}"
  visible="@{calendar.hasSelection}" />
```

Omitting `type` is supported for early experiments and generates `dynamic`,
but typed variables provide better generated-code analysis and should be
preferred.

Simple XML values such as strings, booleans, numbers, colors, insets, common
enums, and theme text styles are converted automatically. Complex values and
callbacks should use binding expressions.

## Static pages and dynamic regions

Generated layout views are `StatelessWidget`s by default. A page can stay
structurally static while one or more small regions observe their own state:

```xml
<Column>
  <Text text="Sign in" style="headlineMedium" />

  <Observe listenable="@{controller}">
    <ElevatedButton
      onPressed="@{controller.isSubmitting ? null : controller.submit}">
      <Text text="@{controller.isSubmitting ? 'Signing in…' : 'Sign in'}" />
    </ElevatedButton>
  </Observe>
</Column>
```

Only the subtree inside `Observe` rebuilds when the controller notifies its
listeners. Multiple independent `Observe` nodes can be used on the same page.

### Listenable

```xml
<Observe listenable="@{controller}">
  <Text text="@{controller.label}" />
</Observe>
```

### ValueListenable

```xml
<Observe valueListenable="@{controller.count}" as="count">
  <Text text="@{count.toString()}" />
</Observe>
```

### Stream

```xml
<Observe stream="@{controller.events}" as="snapshot">
  <Text text="@{snapshot.data?.toString() ?? 'Waiting'}" />
</Observe>
```

These generate local `ListenableBuilder`, `ValueListenableBuilder`, and
`StreamBuilder` boundaries.

Use `visible` to hide a subtree while keeping it alive. Use `if` to
conditionally construct and dispose it:

```xml
<CircularProgressIndicator if="@{controller.isSubmitting}" />
```

## Dynamic collections

SpokeML provides the widget-building mechanism, not a paging implementation.
Fetching, cursors, retries, deduplication, and scroll-trigger policy belong in
the application's controller or a third-party package.

Named builder slots support Flutter's lazy widgets:

```xml
<Observe listenable="@{controller}">
  <ListView.builder itemCount="@{controller.products.length}">
    <Builder name="itemBuilder" args="context,index">
      <Container
        key="@{ValueKey(controller.products[index].id)}"
        padding="16">
        <Text text="@{controller.products[index].name}" />
      </Container>
    </Builder>
  </ListView.builder>
</Observe>
```

When the controller appends products and calls `notifyListeners()`, the local
list region rebuilds and `ListView.builder` creates additional rows lazily.
Stable keys preserve item identity.

For eager `children` collections, use `ForEach`:

```xml
<Column>
  <ForEach
    items="@{products}"
    as="product"
    index="index"
    keyBy="@{product.id}">
    <Text text="@{product.name}" />
  </ForEach>
</Column>
```

## Composition

Use `Include` to compose generated layouts. Relative paths are resolved from
the current XML file, and values are forwarded as constructor arguments:

```xml
<Include
  layout="./product_item.xml"
  product="@{product}"
  onTap="@{controller.openProduct}" />
```

The included layout is tracked as a build dependency, so changes regenerate
dependent outputs. Missing or unknown parameters are validated during
generation.

## Resource lifecycle

Variables are externally owned by default. The Dart parent creates and
disposes them:

```dart
CalendarDemoView(calendar: calendarController)
```

When a layout explicitly owns a resource, SpokeML generates a thin
`StatefulWidget` host while keeping the renderer stateless:

```xml
<variable
  name="controller"
  type="LoginController"
  import="package:my_app/login_controller.dart"
  ownership="owned"
  create="@{LoginController()}" />
```

For a layout named `LoginView`, use the generated `LoginViewHost`. The host
creates the controller, passes it to `LoginView`, and disposes it. Add
`dispose="none"` when an owned object has no `dispose()` method.

This separation keeps view generation predictable:

```text
LoginViewHost (StatefulWidget: ownership and disposal)
└── LoginView (StatelessWidget: XML rendering)
```

## Third-party widgets

Map an XML namespace prefix to a Dart library:

```xml
<layout
  class="CalendarDemoView"
  xmlns:table="package:table_calendar/table_calendar.dart">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:my_app/calendar_controller.dart" />
  </data>

  <table:TableCalendar
    firstDay="@{calendar.firstDay}"
    lastDay="@{calendar.lastDay}"
    focusedDay="@{calendar.focusedDay}"
    selectedDayPredicate="@{calendar.isSelected}"
    onDaySelected="@{calendar.selectDay}" />
</layout>
```

The dependency must also be declared in the application's `pubspec.yaml`.
SpokeML imports the mapped Dart library and validates the generated constructor
against the analyzer. This has been tested with
[`table_calendar`](https://pub.dev/packages/table_calendar).

When a named constructor or third-party widget requires positional arguments,
use contiguous `arg0`, `arg1`, and subsequent attributes:

```xml
<m:Image.asset
  arg0="@{video.thumbnailUrl}"
  fit="@{m.BoxFit.cover}" />
```

SpokeML emits positional arguments before named arguments and validates their
count and ordering.

Use `Slot` for named widget parameters such as `title`, `body`, or `leading`:

```xml
<m:Scaffold>
  <Slot name="body">
    <Text text="Content" />
  </Slot>
</m:Scaffold>
```

## Diagnostics

SpokeML reports XML parsing, schema, constructor, named-parameter, and binding
errors with the XML file, line, and column whenever a source location is
available.

Run Dart analysis through SpokeML to remap downstream generated-code errors:

```sh
dart run spoke_ml analyze
```

Analyze a specific path:

```sh
dart run spoke_ml analyze lib/generated
```

For example, an invalid binding in generated Dart can be reported against its
source expression:

```text
ERROR|COMPILE_TIME_ERROR|ARGUMENT_TYPE_NOT_ASSIGNABLE|
layouts/catalog/product_list.xml|10|36|10|...
```

The analyzer exit code is preserved. Diagnostics without a SpokeML source map
pass through unchanged.

Source mapping is implemented in Dart build tooling, not in Android or Apple
runtime code. The same mechanism therefore applies to Android, iOS, macOS,
Windows, Linux, and web builds.

## Standalone compiler

A single layout can also be compiled without `build_runner`:

```sh
dart run spoke_ml layouts/profile.xml lib/generated/profile.g.dart
```

Omit the output path to print the generated Dart source to stdout.

## Run the example

The repository contains an executable Flutter application demonstrating:

- a third-party `TableCalendar` widget;
- a typed `ChangeNotifier` controller;
- a locally observed dynamic product list;
- stable item keys and lazy builders;
- an owned-controller lifecycle host;
- mirrored grouped layout paths.

```sh
cd example
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Run its tests:

```sh
cd example
flutter test
```

Build platform applications:

```sh
cd example
flutter build apk --debug
flutter build macos --debug
```

## Current scope

Implemented:

- common Flutter layout, text, button, and progress widgets;
- strings, numbers, booleans, enums, colors, insets, and theme text styles;
- typed data variables and Dart binding expressions;
- structural `if` and non-destructive `visible`;
- local `Listenable`, `ValueListenable`, and stream observation;
- generic `ForEach`, stable keys, and named builder callbacks;
- relative layout composition through `Include`;
- external and owned resource lifecycle;
- third-party Dart package namespaces;
- mirrored feature folders;
- XML file, line, column, and expression-range diagnostics;
- analyzer-backed constructor and named-parameter validation.

Planned or incomplete:

- complete static type validation for every callback and expression;
- richer schemas for all Flutter child and builder-slot conventions;
- first-class XML editor/LSP diagnostics and completion;
- a broader built-in widget/value conversion catalog;
- compatibility and golden-test coverage across more Flutter versions.

## Contributing

Before proposing a change, run:

```sh
flutter test
dart analyze
cd example && flutter test
```

Generated `.g.dart` files are intentionally readable. Changes should preserve
normal Flutter semantics and keep state-management policy outside the compiler.

## License

See [LICENSE](LICENSE).
