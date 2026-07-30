## 0.0.1

- Compile XML layouts into Flutter widget source.
- Mirror `layouts/**.xml` into `lib/generated/**.g.dart` with build_runner.
- Preserve XML source locations in compiler diagnostics.
- Generate typed data variables with package imports.
- Support local `Listenable` and `ValueListenable` observation boundaries.
- Support namespaced third-party Flutter widgets.
- Support validated positional constructor arguments through `arg0`, `arg1`,
  and subsequent attributes.
- Accept Dart constant, literal, and closure expressions in bindings.
- Emit `children` correctly when a custom collection contains one `ForEach`.
- Support named widget parameters through `<Slot name="...">`.
