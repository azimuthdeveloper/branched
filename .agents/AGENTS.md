# Behavioral Rules for Branched Workspace

- Use of `setState` is strictly forbidden in this project.
- BLoC (via `flutter_bloc`) must only be used for state management, apart from extreme situations.
- Mocking Git functionality or using dummy placeholder data is strictly forbidden. All operations must run against real Git databases using the integrated git2dart/libgit2 library.

