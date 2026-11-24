<div align="center">

# SpokeML

**Compile XML layouts into ordinary, type-checkable Flutter code**

[![star](https://gitee.com/nottyjay/spoke-ml/badge/star.svg?theme=dark)](https://gitee.com/nottyjay/spoke-ml/stargazers)
[![fork](https://gitee.com/nottyjay/spoke-ml/badge/fork.svg?theme=dark)](https://gitee.com/nottyjay/spoke-ml/members)
[![issue](https://gitee.com/nottyjay/spoke-ml/badge/issue.svg?theme=dark)](https://gitee.com/nottyjay/spoke-ml/issues)

![Dart](https://img.shields.io/badge/Dart-%5E3.10.4-0175C2?logo=dart&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.38.0-02569B?logo=flutter&logoColor=white)
![Status](https://img.shields.io/badge/status-proof%20of%20concept-orange)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Android%20%C2%B7%20iOS%20%C2%B7%20macOS%20%C2%B7%20Windows%20%C2%B7%20Linux%20%C2%B7%20Web-lightgrey)

[English](README.md) | [简体中文](README.zh-CN.md)

</div>

---

## Introduction

SpokeML is an experimental XML-to-Flutter compiler. It lets a Flutter
application describe widget trees in declarative XML files while keeping
state, business logic, and lifecycle policy in ordinary Dart.

```text
layouts/account/login.xml
        │  build_runner
        ▼
lib/generated/account/login.g.dart     ← ordinary Flutter source
```

The generated output is readable, type-checkable Flutter code. There is no
XML parser and no dynamic widget interpreter in the released application —
everything happens at compile time.

**How it works:**

1. Declare the widget tree in XML under `layouts/`; bind values with
   `@{...}` Dart expressions.
2. `build_runner` compiles each XML file into a `.g.dart` widget — a
   stateless renderer, plus an optional thin `StatefulWidget` host when a
   layout owns resources.
3. Your app instantiates the generated views like any hand-written widget,
   passing typed controllers from Dart.

SpokeML explores an Android Data Binding-like workflow for Flutter without
abandoning Flutter's strengths: typed code, tree shaking, and the existing
state-management ecosystem all keep working.

> **Project status:** SpokeML is currently a proof of concept, not a
> production-ready package. Its generator, source mapping, grouped layouts,
> local state boundaries, lifecycle support, and third-party widget
> integration have executable tests. The example has also been built and
> launched on Android and macOS.

## Repository Stats

Live badges above update automatically. Snapshot below was taken from the
Gitee API on **2026-11-24**:

| Metric | Count |
| --- | --- |
| ⭐ Stars | 0 |
| 🍴 Forks | 0 |
| 👁 Watchers | 1 |
| 🐛 Open issues | 0 |

📊 View live numbers on [Gitee](https://gitee.com/nottyjay/spoke-ml).

## Feature Highlights

| Feature | Description |
| --- | --- |
| 🏗 Declarative XML | Common Flutter widgets (`Row`, `Column`, `Stack`, `Positioned`, `Align`, `Container`, `Padding`, `Center`, `SizedBox`, …) are first-class XML elements. |
| 🔒 Typed bindings | `@{...}` expressions are compiled into typed Dart — no runtime string-expression engine. |
| 🎯 Local state boundaries | `Observe` rebuilds only the listening subtree; the page stays `StatelessWidget`. |
| 📋 Lazy collections | `ForEach`, named builder slots, and stable keys for `ListView.builder` and friends. |
| 🧩 Composition | `Include` composes layouts with relative paths and validated parameters. |
| ♻️ Lifecycle ownership | External or owned resources via generated `View` / `ViewHost` pairs. |
| 📦 Third-party widgets | XML namespaces map to Dart packages; tested with `table_calendar`. |
| 🗺 XML source maps | Generator and downstream Dart errors are reported back at the XML file, line, column, and expression range. |

## Example Guide

The runnable Flutter app under [`example/`](example/) demonstrates every
major feature. Each XML layout mirrors its generated output path
one-to-one.

| # | Example | Layout file | Demonstrates |
| --- | --- | --- | --- |
| 1 | [Profile](example/layouts/profile.xml) | `example/layouts/profile.xml` | Basic layout, auto value conversion, `visible` |
| 2 | [Include](example/layouts/include_demo.xml) | `example/layouts/include_demo.xml` | Layout composition, parameter forwarding |
| 3 | [Catalog list](example/layouts/catalog/product_list.xml) | `example/layouts/catalog/product_list.xml` | Local observation, lazy `ListView.builder`, stable keys |
| 4 | [TableCalendar](example/layouts/calendar/table_calendar.xml) | `example/layouts/calendar/table_calendar.xml` | Third-party widget via XML namespace |
| 5 | [Owned lifecycle](example/layouts/lifecycle/calendar_owned.xml) | `example/layouts/lifecycle/calendar_owned.xml` | Owned controller with generated `Host` |

### 1. Profile — static layout with conditions

`example/layouts/profile.xml` renders a simple profile card. Simple
attributes (`width`, `padding`, `color`, `height`, `textAlign`) are
converted automatically; dynamic values use `@{...}` bindings; `visible`
hides a subtree without destroying it.

```xml
<layout class="ProfileView">
  <data>
    <variable name="user" />
    <variable name="form" />
    <variable name="controller" />
  </data>

  <Center>
    <Container width="420" padding="24" color="#F5F5F5">
      <Column mainAxisSize="min" crossAxisAlignment="stretch">
        <Text text="@{user.name}" style="headlineMedium" textAlign="center" />
        <SizedBox height="12" />
        <Text
          text="请确认资料后保存"
          textAlign="center"
          visible="@{form.showHint}" />
        <SizedBox height="24" />
        <ElevatedButton onPressed="@{controller.save}">
          <Text text="保存" />
        </ElevatedButton>
      </Column>
    </Container>
  </Center>
</layout>
```

Generated output: `example/lib/generated/profile.g.dart`.

### 2. Include — layout composition

`example/layouts/include_demo.xml` composes the profile layout and forwards
all three variables. Relative paths resolve against the current XML file,
and the included layout becomes a tracked build dependency.

```xml
<layout class="IncludeDemoView">
  <data>
    <variable name="user" />
    <variable name="form" />
    <variable name="controller" />
  </data>

  <Include
    layout="./profile.xml"
    user="@{user}"
    form="@{form}"
    controller="@{controller}" />
</layout>
```

Generated output: `example/lib/generated/include_demo.g.dart`, which
imports and instantiates the generated `ProfileView`.

### 3. Catalog list — local observation and lazy builders

`example/layouts/catalog/product_list.xml` combines an `Observe` boundary
with `ListView.builder`. When the controller appends products and calls
`notifyListeners()`, only the list region rebuilds and rows are created
lazily. `ValueKey` keeps item identity stable.

```xml
<layout class="ProductListView">
  <data>
    <variable
      name="controller"
      type="CatalogController"
      import="package:spoke_ml_example/catalog_controller.dart" />
  </data>

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
</layout>
```

Controller: `example/lib/catalog_controller.dart` — an append-only demo
`CatalogController`. Generated output:
`example/lib/generated/catalog/product_list.g.dart`. The example app adds a
button that appends five products per tap so you can watch the region update
live.

### 4. TableCalendar — third-party widget

`example/layouts/calendar/table_calendar.xml` maps the `table:` namespace
prefix to `package:table_calendar/table_calendar.dart`. SpokeML imports the
library, validates the generated constructor call with the analyzer, and
supports callbacks such as `onDaySelected`.

```xml
<layout
  class="CalendarDemoView"
  xmlns:table="package:table_calendar/table_calendar.dart">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:spoke_ml_example/calendar_controller.dart" />
  </data>

  <Center>
    <Container width="420" padding="16" color="#F5F5F5">
      <Column mainAxisSize="min" crossAxisAlignment="stretch">
        <Text
          text="第三方 TableCalendar"
          style="titleLarge"
          textAlign="center" />
        <SizedBox height="12" />
        <Observe listenable="@{calendar}">
          <Column mainAxisSize="min" crossAxisAlignment="stretch">
            <table:TableCalendar
              firstDay="@{calendar.firstDay}"
              lastDay="@{calendar.lastDay}"
              focusedDay="@{calendar.focusedDay}"
              selectedDayPredicate="@{calendar.isSelected}"
              onDaySelected="@{calendar.selectDay}"
              rowHeight="48" />
            <SizedBox height="12" />
            <Text text="@{calendar.selectionLabel}" textAlign="center" />
          </Column>
        </Observe>
      </Column>
    </Container>
  </Center>
</layout>
```

Controller: `example/lib/calendar_controller.dart`. Generated output:
`example/lib/generated/calendar/table_calendar.g.dart`. The pure-Dart
`table_calendar` package works on all platforms without extra plugin setup.

### 5. Owned lifecycle — generated Host

`example/layouts/lifecycle/calendar_owned.xml` declares an owned variable.
SpokeML generates a thin `StatefulWidget` host (`OwnedCalendarLabelViewHost`)
that creates the controller, passes it to the stateless renderer, and
disposes it — while `OwnedCalendarLabelView` itself remains `StatelessWidget`.

```xml
<layout class="OwnedCalendarLabelView">
  <data>
    <variable
      name="calendar"
      type="CalendarController"
      import="package:spoke_ml_example/calendar_controller.dart"
      ownership="owned"
      create="@{CalendarController()}" />
  </data>

  <Observe listenable="@{calendar}">
    <Text text="@{calendar.selectionLabel}" />
  </Observe>
</layout>
```

Generated output:
`example/lib/generated/lifecycle/calendar_owned.g.dart`.

### Run the example

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

The example has been built and launched as a native Android APK and a native
macOS Debug app with Flutter 3.38.5.

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

## Quick Start

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

## Documentation

- [Layout organization](#layout-organization) — mirrored input/output folders
- [Data and expressions](#data-and-expressions) — variables and `@{...}` bindings
- [Static pages and dynamic regions](#static-pages-and-dynamic-regions) — `Observe`, `if`, `visible`
- [Dynamic collections](#dynamic-collections) — `ForEach`, builder slots, stable keys
- [Composition](#composition) — `Include`
- [Resource lifecycle](#resource-lifecycle) — external vs owned variables
- [Third-party widgets](#third-party-widgets) — namespaces, positional args, slots
- [Diagnostics](#diagnostics) — XML source mapping and `spoke_ml analyze`
- [Standalone compiler](#standalone-compiler) — compile one file without build_runner

### Layout organization

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

### Data and expressions

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

### Static pages and dynamic regions

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

**Listenable:**

```xml
<Observe listenable="@{controller}">
  <Text text="@{controller.label}" />
</Observe>
```

**ValueListenable:**

```xml
<Observe valueListenable="@{controller.count}" as="count">
  <Text text="@{count.toString()}" />
</Observe>
```

**Stream:**

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

### Dynamic collections

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

### Composition

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

### Resource lifecycle

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

### Third-party widgets

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

### Diagnostics

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

### Standalone compiler

A single layout can also be compiled without `build_runner`:

```sh
dart run spoke_ml layouts/profile.xml lib/generated/profile.g.dart
```

Omit the output path to print the generated Dart source to stdout.

## Current Scope

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

SpokeML is released under the [MIT License](LICENSE).

---

<div align="center">

⭐ If SpokeML interests you, a star on
[Gitee](https://gitee.com/nottyjay/spoke-ml) helps others find it.

</div>
