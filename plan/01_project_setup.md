# 01 — Project Setup & Dependencies

## Flutter Project Initialization

```bash
flutter create --platforms=windows,macos,linux --org=com.furcate furcate
```

| Requirement | Value |
|-------------|-------|
| Flutter SDK | ≥ 3.22.0 (latest stable) |
| Dart SDK | ≥ 3.4.0 |
| Target Platforms | macOS, Linux, Windows (desktop only) |

---

## Dependencies (pubspec.yaml)

### State Management

| Package | Purpose |
|---------|---------|
| `flutter_bloc: ^8.1.0` | BlocProvider, BlocBuilder, BlocListener, BlocConsumer |
| `bloc: ^8.1.0` | Core Bloc/Cubit classes |
| `equatable: ^2.0.0` | Value equality for states and events |
| `bloc_concurrency: ^0.2.0` | Event transformers (droppable, restartable, sequential) |
| `hydrated_bloc: ^9.1.0` | Automatically persist/restore bloc states to disk |
| `replay_bloc: ^0.2.0` | Undo/redo support (for interactive rebase) |

### Git Engine

| Package | Purpose |
|---------|---------|
| `git2dart: ^1.x.x` | libgit2 Dart bindings — all git operations |

### Dependency Injection

| Package | Purpose |
|---------|---------|
| `get_it: ^8.0.0` | Service locator |
| `injectable: ^2.4.0` | Code-gen annotations for get_it |
| `injectable_generator: ^2.6.0` | (dev) Code generator |

### Code Generation

| Package | Purpose |
|---------|---------|
| `freezed_annotation: ^2.4.0` | Annotations for immutable classes |
| `freezed: ^2.5.0` | (dev) Code generator for states/models |
| `json_serializable: ^6.8.0` | (dev) JSON serialization codegen |
| `json_annotation: ^4.9.0` | JSON annotations |
| `build_runner: ^2.4.0` | (dev) Runs code generators |

### Desktop / Window Management

| Package | Purpose |
|---------|---------|
| `bitsdojo_window: ^0.1.6` | Custom title bar, window buttons, drag area |
| `macos_window_utils: ^1.5.0` | macOS: traffic lights, vibrancy, transparency |
| `window_manager: ^0.4.0` | Window size persistence, positioning, events |

### UI Components

| Package | Purpose |
|---------|---------|
| `flutter_svg: ^2.0.0` | SVG icon rendering |
| `google_fonts: ^6.2.0` | JetBrains Mono for code/diff display |
| `re_highlight: ^0.3.0` | Syntax highlighting for diff viewer |
| `super_context_menu: ^1.x.x` | Platform-native context menus |
| `multi_split_view: ^3.x.x` | Resizable split panels |
| `linked_scroll_controller: ^0.2.0` | Synchronized scrolling for side-by-side diff |
| `flutter_fancy_tree_view: ^1.x.x` | Sidebar tree view with expand/collapse |

### Local Storage

| Package | Purpose |
|---------|---------|
| `hive: ^4.0.0` | Fast key-value storage (recent repos, preferences) |
| `hive_flutter: ^2.0.0` | Flutter integration for Hive |
| `path_provider: ^2.1.0` | App data directory paths per platform |
| `shared_preferences: ^2.3.0` | Simple key-value for quick settings |

### Utilities

| Package | Purpose |
|---------|---------|
| `dartz: ^0.10.0` | `Either<Failure, Success>` for error handling |
| `rxdart: ^0.28.0` | Stream transformers (debounce, throttle) |
| `path: ^1.9.0` | Cross-platform file path manipulation |
| `collection: ^1.18.0` | Advanced list/map utilities |
| `intl: ^0.19.0` | Date formatting, localization |
| `logging: ^1.2.0` | Structured logging |
| `watcher: ^1.1.0` | File system watching |
| `uuid: ^4.5.0` | Unique identifiers for tabs, operations |

### Testing (dev_dependencies)

| Package | Purpose |
|---------|---------|
| `bloc_test: ^9.1.0` | BLoC-specific test utilities |
| `mocktail: ^1.0.0` | Mock generation without codegen |
| `golden_toolkit: ^0.15.0` | Pixel-perfect golden image tests |
| `very_good_analysis: ^6.0.0` | Strict lint rules |
| `integration_test:` (SDK) | Desktop integration tests |

---

## Native Dependencies per Platform

### Linux

```bash
sudo apt-get install -y \
  libssl-dev \
  libpcre3 \
  libgtk-3-dev \
  libblkid-dev \
  liblzma-dev \
  pkg-config \
  cmake \
  ninja-build \
  clang
```

### macOS

```bash
brew install openssl cmake
xcode-select --install
```

> [!NOTE]
> Xcode command line tools are required. Disable App Sandbox in `macos/Runner/Release.entitlements` and `DebugProfile.entitlements` to allow file system access.

### Windows

```powershell
choco install openssl -y
choco install cmake -y
# Visual Studio 2022 with "Desktop development with C++" workload
```

---

## Build Configuration

### Linux (`linux/CMakeLists.txt`)
- Link against libgit2 shared library bundled by git2dart
- Set `RPATH` for portable binary distribution
- Bundle required `.so` files in the application directory

### macOS (`macos/Runner.xcodeproj`)
- Disable App Sandbox entitlement (needs file system + network access)
- Add `com.apple.security.network.client` entitlement
- Add `com.apple.security.files.user-selected.read-write` entitlement
- Set minimum macOS deployment target to 11.0
- Configure code signing for distribution

### Windows (`windows/CMakeLists.txt`)
- Bundle `git2.dll` and `libssl` DLLs with the application
- Set application icon via `Runner.rc`
- Configure MSIX packaging for Microsoft Store (optional)

---

## App Icon Setup

| Platform | Location | Format |
|----------|----------|--------|
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/` | Multiple PNG sizes + `Contents.json` |
| Linux | `linux/app_icon.png` + `.desktop` file | 256×256 PNG minimum |
| Windows | `windows/runner/resources/app_icon.ico` | Multi-size ICO (16–256px) |

---

## Development Workflow

### Code Generation (run continuously during development)

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### Linting

```yaml
# analysis_options.yaml
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    public_member_api_docs: false  # Optional: enable for public API docs
```

### Git Hooks (pre-commit)

```bash
#!/bin/sh
# .git/hooks/pre-commit
dart format --set-exit-if-changed lib/ test/
dart analyze --fatal-infos
```

### Environment Setup Script

```bash
#!/bin/bash
# scripts/setup.sh
echo "Installing dependencies..."
flutter pub get
echo "Running code generation..."
dart run build_runner build --delete-conflicting-outputs
echo "Setup complete!"
```

---

## CI/CD Considerations

| Step | Tool | Notes |
|------|------|-------|
| Lint & Format | `dart analyze` + `dart format` | Fail on warnings |
| Unit Tests | `flutter test` | Run on all platforms |
| Build (Linux) | GitHub Actions Ubuntu runner | Install native deps first |
| Build (macOS) | GitHub Actions macOS runner | Xcode + Homebrew deps |
| Build (Windows) | GitHub Actions Windows runner | Chocolatey + VS Build Tools |
| Packaging | Platform-specific | DMG (macOS), AppImage/deb (Linux), MSIX/exe (Windows) |
| Release | GitHub Releases | Automated from tags |

---

## Initial Project Checklist

- [ ] Create Flutter project with desktop platforms
- [ ] Add all dependencies to `pubspec.yaml`
- [ ] Install native dependencies on dev machine
- [ ] Configure analysis_options.yaml
- [ ] Set up `get_it` / `injectable` DI container
- [ ] Create base folder structure (core/, features/, git_engine/)
- [ ] Configure `bitsdojo_window` for each platform
- [ ] Run `build_runner` to verify code generation works
- [ ] Create initial app shell with empty window
- [ ] Verify builds on all three platforms
