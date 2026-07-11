# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Branched** (app name in UI: "Furcate") is a cross-platform Git client built with Flutter, targeting macOS, Linux, Windows, and Android. Git operations run natively through `git2dart` (libgit2 FFI bindings) — there is no dependency on the system `git` CLI at runtime.

## Commands

```bash
flutter pub get                  # resolve dependencies
flutter analyze                  # lint (flutter_lints ruleset)
flutter run -d macos             # run app (also: -d linux, -d windows, or an Android device)

# Unit/widget tests
flutter test                     # all tests in test/
flutter test test/bare_repo_flow_test.dart          # single test file
flutter test --plain-name "name of test"            # single test by name

# Integration tests (drive the real UI; on Linux headless they need Xvfb — see run_integration_test.sh)
flutter test -d macos integration_test/branch_merge_flow_test.dart   # uses MockGitService
flutter test -d macos integration_test/real_git_flow_test.dart       # uses RealGitService on a scratch repo

./install_macos.sh               # build macOS release and copy to /Applications
./run_integration_test.sh        # Linux headless integration run (Xvfb + openbox)
./record_integration_test.sh     # same, with ffmpeg screen recording to integration_test_recordings/
```

## Architecture

Strict BLoC state management (`flutter_bloc` + `equatable`) — no `setState`. Dependency injection via `get_it`; feature-first folder layout.

### Layers

- `lib/git_engine/` — the data layer, decoupled from Flutter:
  - `git_service.dart` — abstract `GitService` interface covering all Git operations (branches, commits, staging, diff, merge/rebase, remotes, tags, stashes, submodules) plus the `GitRepo` handle.
  - `git_service_impl.dart` — `RealGitService`, the production implementation on top of `git2dart`/libgit2 FFI. FFI resources must be released; recent work uses memory-safe release blocks. Throws `GitException` on failures.
  - `mock_git_service.dart` — in-memory `MockGitService` used by widget/integration tests that don't need a real repo.
  - `git_models.dart` — immutable entities (`CommitEntity`, `BranchEntity`, `WorkingCopyStatus`, `FileDiffEntity`, etc.).
- `lib/core/locator.dart` — `setupLocator()` registers `GitService` and `FilePickerService` singletons. Tests swap in mocks by registering different implementations before pumping the app.
- `lib/core/theme.dart` — `FurcateTheme`, dark theme constants used directly throughout widgets.
- `lib/features/<feature>/` — each feature pairs a BLoC with its widgets:
  - `repository_manager/` — `RepositoryManagerBloc` owns the tab list (`RepoTab`), open/clone/init flows, and recent-repos persistence via `SharedPreferences`. Provided app-wide in `main.dart`; no active tab → `WelcomeScreen`.
  - `repository/` — `MainWorkspace` is the per-repository shell. It creates a `MultiBlocProvider` with `RepositoryBloc`, `SidebarBloc`, `CommitGraphBloc`, `StagingBloc`, and `DiffViewerBloc` — all scoped to the active tab (keyed by tab id, so switching tabs rebuilds them). Also contains the file browser (`file_browser_bloc.dart`) used for bare-repository remote file editing.
  - `commit_graph/` — graph layout (`graph_layout.dart`) and `CustomPainter` rendering (`commit_graph_painter.dart`).
  - `sidebar/`, `staging/`, `diff_viewer/`, `window_chrome/` — corresponding panels.

### App flow

`main.dart` → `setupLocator()` → `FurcateApp` → `AppContentGate`, which gates on window width (< 580px shows an "unfold" prompt for folding phones) and on whether a repo tab is active (`WelcomeScreen` vs `MainWorkspace`).

## Testing conventions

- `test/` unit tests register mock `GitService`/`FilePickerService` implementations into the `get_it` locator before building widgets.
- `integration_test/real_git_flow_test.dart` builds a real scratch Git repository via a `TestRepoBuilder` helper (branches, submodules, stashes — no network) and drives the UI against `RealGitService`. `testing.md` documents the full scenario matrix this suite covers.
- Bare-repository flows have dedicated unit coverage in `test/bare_repo_flow_test.dart`.

## Reference docs

- `plan/` — original design docs (00–17) covering architecture, each feature, and milestones. Note some listed tech (freezed, hive, bitsdojo_window) was not adopted; the code is the source of truth.
- `upgrades.md` — known-gaps / production-readiness backlog, including open bugs.
- `testing.md` — integration test plan and scenario descriptions.
