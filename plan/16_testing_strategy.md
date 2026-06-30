# 16 — Testing Strategy

## Overview

Comprehensive testing ensures Furcate is reliable across all three platforms. The strategy covers unit tests, BLoC tests, widget tests, integration tests, and golden tests.

---

## Testing Pyramid

```
         ╱╲
        ╱  ╲          E2E / Integration Tests
       ╱    ╲         (10% — full app flows)
      ╱──────╲
     ╱        ╲       Widget Tests
    ╱          ╲      (20% — UI components)
   ╱────────────╲
  ╱              ╲    BLoC / Unit Tests
 ╱                ╲   (70% — business logic)
╱──────────────────╲
```

---

## 1. Unit Tests (Domain + Data Layer)

### What to Test

| Component | Tests |
|-----------|-------|
| **Entities** | Equality, copyWith, serialization |
| **Use Cases** | Business logic, input validation, error mapping |
| **Repositories** (data layer) | Data transformation, error handling |
| **GitService** | All method behaviors (via mocked git2dart) |
| **GitAuthHandler** | Credential resolution logic |
| **Graph Algorithm** | Lane assignment, connection generation |
| **Search/Filter** | Fuzzy matching, query parsing |
| **Models** | Freezed class generation, fromJson/toJson |

### Mocking Strategy

- **`mocktail`** for all mocks (no codegen needed)
- Mock `git2dart` Repository, Branch, Commit, etc.
- Mock `GitService` interface for use case tests
- Mock `HiveBox` for persistence tests
- Mock `flutter_secure_storage` for credential tests

### Example Test Patterns

```
test/
├── core/
│   └── extensions/
│       └── string_extensions_test.dart
├── features/
│   ├── commit_graph/
│   │   ├── data/
│   │   │   └── graph_builder_test.dart
│   │   └── domain/
│   │       └── build_graph_use_case_test.dart
│   ├── staging/
│   │   └── domain/
│   │       └── stage_file_use_case_test.dart
│   └── ...
└── git_engine/
    ├── git_service_test.dart
    ├── git_auth_handler_test.dart
    └── git_graph_builder_test.dart
```

### Graph Algorithm Tests

Critical test cases for the lane assignment algorithm:

| Scenario | Expected |
|----------|----------|
| Linear history (no branches) | All commits in lane 0 |
| Simple branch + merge | 2 lanes, merge connection |
| Multiple parallel branches | N lanes, correct connections |
| Octopus merge (3+ parents) | Multiple merge connections |
| Orphan branch | Separate lane group |
| Long-running branch | Lane persists across many rows |
| Complex merge graph | Correct lane reuse after branch ends |

---

## 2. BLoC Tests

### Tools

- `bloc_test` package for structured BLoC testing
- `setUp` → create BLoC with mocked dependencies
- `blocTest()` for declarative act/expect patterns

### What to Test per BLoC

| BLoC | Key Test Cases |
|------|---------------|
| **AppBloc** | Initialization flow, error handling |
| **RepositoryManagerBloc** | Open/close/switch tabs, reorder, clone |
| **RepositoryBloc** | Load repo, refresh, file watcher events |
| **SidebarBloc** | Load data, toggle sections, select items, filter |
| **CommitGraphBloc** | Load history, pagination, select commit, filter by branch, search |
| **StagingBloc** | Load working copy, stage/unstage file, stage all, discard |
| **CommitFormCubit** | Update message, toggle amend, submit, validation |
| **DiffViewerBloc** | Load diff, toggle mode, handle binary files |
| **BranchOperationBloc** | Create/delete/rename/checkout, merge, rebase, conflict handling |
| **RemoteOpsBloc** | Fetch/pull/push, progress updates, error handling, auth failure |
| **StashBloc** | Create/apply/pop/drop |
| **SearchBloc** | Search with debounce, clear, result handling |
| **ConflictResolutionBloc** | Load conflicts, resolve file, mark resolved, abort |
| **ThemeCubit** | Theme toggle, persistence |
| **PanelLayoutCubit** | Resize, reset, persistence |

### BLoC Test Template

```
blocTest<CommitGraphBloc, CommitGraphState>(
  'emits loaded state when LoadCommitHistory succeeds',
  build: () {
    when(() => mockGitService.getCommitHistory(...))
        .thenAnswer((_) async => Right(mockCommits));
    return CommitGraphBloc(gitService: mockGitService);
  },
  act: (bloc) => bloc.add(LoadCommitHistory()),
  expect: () => [
    CommitGraphState.loading(),
    CommitGraphState.loaded(commits: mockGraphCommits, hasMore: true),
  ],
);
```

### Event Transformer Tests

| BLoC | Test |
|------|------|
| CommitGraphBloc | Rapid LoadMoreCommits events → only one processed (droppable) |
| SearchBloc | Rapid SearchCommits → only last one processed (restartable) |
| RemoteOpsBloc | Multiple Push events → processed sequentially |
| StagingBloc | Stage/Unstage ordering maintained (sequential) |

---

## 3. Widget Tests

### What to Test

| Widget | Tests |
|--------|-------|
| **SidebarWidget** | Renders tree, expand/collapse, selection, context menu |
| **CommitListRow** | Renders commit info, selection highlight, labels |
| **DiffLine** | Correct colors for add/delete/context, syntax highlighting |
| **FileStatusRow** | Correct icon and color per status |
| **ToolbarButton** | Enabled/disabled states, click handler, hover |
| **BranchLabel** | Correct style per type (local, remote, tag) |
| **CommitForm** | Input validation, submit button state, amend toggle |
| **SettingsPanel** | All settings rendered, changes dispatched |
| **WelcomeScreen** | Recent repos list, buttons, drag-drop target |
| **CloneDialog** | URL parsing, validation, progress bar |
| **ConflictDialog** | File list, resolution options |

### Widget Test Patterns

- Wrap widgets in `BlocProvider` with mock BLoC
- Use `whenListen` to provide state streams
- Test both UI rendering and user interactions
- Test accessibility (Semantics)

---

## 4. Golden Tests

### Purpose

Pixel-perfect verification that UI matches the Branched design specification.

### Tools

- `golden_toolkit` package
- Custom `GoldenFileComparator` with platform-aware comparison

### Golden Test Cases

| Test | Description |
|------|-------------|
| Full app (dark theme) | Complete layout screenshot |
| Full app (light theme) | Complete layout screenshot |
| Sidebar (expanded) | All sections expanded |
| Sidebar (collapsed) | Sections collapsed, minimal |
| Commit graph (simple) | Linear history |
| Commit graph (complex) | Multiple branches, merges |
| Diff viewer (unified) | Add/delete/context lines |
| Diff viewer (split) | Side-by-side view |
| Working copy view | Staged/unstaged files + commit form |
| Toolbar (all enabled) | All buttons active |
| Toolbar (disabled states) | Various disabled combinations |
| Context menu | Branch context menu open |
| Clone dialog | With progress bar |
| Conflict resolution | Conflicted files list |
| Settings window | General settings page |
| Welcome screen | With recent repos |

### Platform-Specific Goldens

- Generate separate golden files per platform (fonts differ)
- Store in `test/goldens/{platform}/`
- CI runs golden tests on each platform

---

## 5. Integration Tests

### Tools

- Flutter `integration_test` package
- Run on each platform (macOS, Linux, Windows)

### Test Scenarios

| Scenario | Steps |
|----------|-------|
| **Open Repository** | Launch app → Open repo → Verify sidebar loads → Verify graph loads |
| **Stage and Commit** | Modify file → See in unstaged → Stage → Write message → Commit → Verify in graph |
| **Branch Operations** | Create branch → Checkout → Make commit → Switch back → Merge |
| **Stash Flow** | Make changes → Stash → Verify clean → Pop → Verify changes restored |
| **Clone Flow** | Enter URL → Clone → Verify repo opens → Verify commits visible |
| **Tab Management** | Open 3 repos → Switch tabs → Close tab → Verify state preserved |
| **Search** | Type query → Verify filtered results → Clear → Verify all results |
| **Conflict Resolution** | Create conflicting branches → Merge → Resolve conflicts → Commit |

### Test Repo Fixture

Create a test repository fixture in `test/fixtures/test_repo/`:
- Pre-populated git repository
- Multiple branches with known history
- Known commit SHAs for assertions
- Generated by a setup script

---

## 6. Performance Tests

| Test | Metric | Target |
|------|--------|--------|
| App startup | Time to first frame | < 2s |
| Open large repo (10K commits) | Time to render graph | < 3s |
| Scroll graph (10K commits) | Frame rate during scroll | 60fps |
| Load diff (large file) | Time to render diff | < 1s |
| Stage 100 files | Time to complete | < 2s |
| Search 10K commits | Time to show results | < 500ms |

### How to Measure

- Use Flutter's DevTools performance overlay
- Benchmark tests with `flutter_test` benchmark API
- CI pipeline runs performance regression tests

---

## CI/CD Testing Pipeline

```
┌──────────────────────────────────────────────┐
│                   CI Pipeline                 │
├──────────────────────────────────────────────┤
│                                               │
│  1. dart analyze (lint)                       │
│  2. dart format --set-exit-if-changed         │
│  3. flutter test (unit + BLoC + widget)       │
│  4. flutter test --update-goldens (if needed) │
│  5. Build (macOS / Linux / Windows)           │
│  6. Integration tests on each platform        │
│                                               │
│  Trigger: Every PR and push to main           │
│  Matrix: [macOS, ubuntu, windows] runners     │
│                                               │
└──────────────────────────────────────────────┘
```

---

## Coverage Targets

| Layer | Target |
|-------|--------|
| Domain (Use Cases, Entities) | ≥ 90% |
| Data (Repositories, Git Engine) | ≥ 80% |
| BLoCs/Cubits | ≥ 90% |
| Widgets | ≥ 60% |
| Integration | All critical paths |
| Overall | ≥ 75% |

---

## Test File Naming Convention

```
{feature_name}_test.dart              # Unit test
{feature_name}_bloc_test.dart         # BLoC test
{widget_name}_widget_test.dart        # Widget test
{feature_name}_golden_test.dart       # Golden test
{scenario_name}_integration_test.dart # Integration test
```
