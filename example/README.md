# SpokeML executable example

Generate both example layouts from the repository structure:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Use watch mode while editing files under `layouts/`:

```sh
dart run build_runner watch --delete-conflicting-outputs
```

The calendar layout demonstrates a typed controller, a local `Observe`
boundary, and the third-party `table_calendar` package:

```text
layouts/calendar/table_calendar.xml
→ lib/generated/calendar/table_calendar.g.dart
```

Run it on a connected Android device:

```sh
flutter run -d <android-device-id>
```

Build an installable debug APK:

```sh
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

