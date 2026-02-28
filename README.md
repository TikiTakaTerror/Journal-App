# AI Journal (Phase 1 Scaffold)

Privacy-first journaling app built with Flutter for iOS, Android, Web, and Desktop.

## Phase 1 Scope Implemented

- Layered architecture (`domain`, `data`, `presentation`)
- Riverpod-based state management
- Journal entry model with input validation + serialization
- Local storage service abstraction + SQLCipher-backed implementation
- Secure local key management via `flutter_secure_storage`
- Basic distraction-free journal editor UI
- Test-first implementation with unit, widget, and integration test files

## Architecture

```text
lib/
  app/
    app.dart
    providers.dart
  core/
    platform/
    security/
  features/journal/
    domain/
      models/
      repositories/
    data/
      local/
      repositories/
    presentation/
      pages/
      state/
```

## State Management Choice

Riverpod (`flutter_riverpod`) is used for:

- Dependency injection (storage, repository, security services)
- Controller lifecycle management
- Predictable state updates in `JournalEditorController`

## Security Notes

- Encrypted DB path uses SQLCipher on Android/iOS.
- DB encryption key is generated and persisted in secure storage.
- SQL queries use parameterized arguments for filtering and deletes.
- On unsupported runtimes (e.g., web/desktop in this scaffold), a non-encrypted in-memory fallback is used to keep the app runnable.

## Run

```bash
flutter pub get
flutter run
```

For development with OpenAI config from `.secrets/openai.dev.json`:

```bash
./tool/run_dev.sh
```

Or manually:

```bash
flutter run --dart-define-from-file=.secrets/openai.dev.json --dart-define=OPENAI_DEBUG_LOGS=true
```

Important: a file in `.secrets/` is not loaded automatically. The app only sees those values when passed via `--dart-define`/`--dart-define-from-file` or when you store a key in `Settings`.

## Tests

```bash
flutter test
flutter analyze
```

Integration tests are scaffolded in `integration_test/`. Running them requires a supported integration device toolchain (`xcodebuild` for macOS/iOS or emulator/device setup).
