# 03 — State Management (BLoC Architecture)

## Core Principles

1. **Absolutely NO `setState`** anywhere in the codebase
2. All BLoC states use `freezed` for immutability
3. All events and states extend `Equatable`
4. Use `bloc_concurrency` event transformers for controlling concurrency
5. Use `HydratedBloc` / `HydratedCubit` for persisted states
6. Use `MultiBlocProvider` at app root for global blocs
7. Use `BlocProvider` at feature level for scoped blocs
8. BLoC-to-BLoC communication via `BlocListener` (never direct references)

---

## BLoC Hierarchy Diagram

```
App Root (MultiBlocProvider)
├── AppBloc                          ← App lifecycle
├── ThemeCubit (Hydrated)            ← Theme persistence
├── RepositoryManagerBloc            ← Tab management
├── RecentRepositoriesCubit (Hydrated) ← Recent repos
├── KeyboardShortcutCubit            ← Global shortcuts
└── PanelLayoutCubit (Hydrated)      ← Panel sizes
    │
    └── Per-Repository Tab (MultiBlocProvider)
        ├── RepositoryBloc           ← Repo lifecycle
        ├── SidebarBloc              ← Sidebar tree
        ├── CommitGraphBloc          ← DAG data
        ├── CommitDetailBloc         ← Selected commit
        ├── StagingBloc              ← Working copy
        ├── CommitFormCubit          ← Commit message
        ├── DiffViewerBloc           ← Diff display
        ├── BranchOperationBloc      ← Branch CRUD
        ├── RemoteOpsBloc            ← Push/pull/fetch
        ├── StashBloc                ← Stash ops
        ├── TagBloc                  ← Tag management
        ├── SearchBloc               ← Search
        └── ConflictResolutionBloc   ← Merge conflicts
```

---

## Global Blocs (Provided at App Root)

### 1. AppBloc

| | Detail |
|---|--------|
| **Purpose** | Application lifecycle, initialization, global error handling |

**Events:**
| Event | Payload | Description |
|-------|---------|-------------|
| `AppStarted` | — | Fired on app launch |
| `AppSettingsLoaded` | `AppSettings` | Settings loaded from disk |
| `AppErrorOccurred` | `String message` | Global error |

**States:**
| State | Fields | Description |
|-------|--------|-------------|
| `AppInitial` | — | Pre-initialization |
| `AppLoading` | — | Loading settings, git engine |
| `AppReady` | `AppSettings settings` | Ready to use |
| `AppError` | `String message` | Fatal error |

---

### 2. ThemeCubit (HydratedCubit)

| | Detail |
|---|--------|
| **Purpose** | Persists theme mode (light/dark/system) and accent color |

**State:**
```
ThemeState {
  ThemeMode themeMode,       // light, dark, system
  Color accentColor,         // default: #0078D4
  bool useSystemAccent,      // follow OS accent color
}
```

**Methods:**
- `setThemeMode(ThemeMode)`
- `setAccentColor(Color)`
- `toggleSystemAccent()`

---

### 3. RepositoryManagerBloc

| | Detail |
|---|--------|
| **Purpose** | Manages open repository tabs — open, close, switch, reorder |

**Events:**
| Event | Payload |
|-------|---------|
| `OpenRepository` | `String path` |
| `CloseRepository` | `int tabIndex` |
| `SwitchTab` | `int tabIndex` |
| `ReorderTabs` | `int oldIndex, int newIndex` |
| `CloneRepository` | `String url, String path, Credentials?` |
| `InitRepository` | `String path` |

**State:**
```
RepositoryManagerState {
  List<RepoTab> openTabs,       // all open repo tabs
  int activeTabIndex,           // currently active tab
  bool isCloning,               // clone in progress
  double? cloneProgress,        // 0.0–1.0
  String? error,
}

RepoTab {
  String id,                    // UUID
  String path,                  // filesystem path
  String name,                  // display name (repo folder name)
  bool isDirty,                 // has uncommitted changes
}
```

---

### 4. RecentRepositoriesCubit (HydratedCubit)

| | Detail |
|---|--------|
| **Purpose** | Persists list of recently opened repositories |

**State:** `List<RepoInfo>`

```
RepoInfo {
  String path,
  String name,
  DateTime lastOpened,
  bool pinned,
}
```

**Methods:**
- `addRecent(RepoInfo)` — adds to front, deduplicates, caps at 20
- `removeRecent(String path)`
- `pinRepo(String path)`
- `unpinRepo(String path)`
- `clearAll()`

---

### 5. PanelLayoutCubit (HydratedCubit)

| | Detail |
|---|--------|
| **Purpose** | Persists resizable panel dimensions |

**State:**
```
PanelLayoutState {
  double sidebarWidth,          // default: 220.0
  double mainSplitRatio,        // default: 0.6 (top 60%)
  double detailSplitRatio,      // default: 0.3 (files 30%)
  bool sidebarCollapsed,        // default: false
}
```

---

## Per-Repository Blocs (Scoped per Tab)

### 6. RepositoryBloc

| | Detail |
|---|--------|
| **Purpose** | Root bloc for a single repository — loads, refreshes, watches for changes |

**Events:**
| Event | Payload |
|-------|---------|
| `LoadRepository` | `String path` |
| `RefreshRepository` | — (triggered by file watcher) |
| `RepositoryFileChanged` | `FileChangeEvent` |

**States:**
| State | Fields |
|-------|--------|
| `RepositoryInitial` | — |
| `RepositoryLoading` | `String path` |
| `RepositoryLoaded` | `Repository repo, Branch currentBranch, Commit headCommit, bool hasUncommittedChanges` |
| `RepositoryError` | `String message, String path` |

**Behavior:**
- On `LoadRepository`: open via GitService, load branch info, start file watcher
- On file watcher change: dispatch `RefreshRepository` (debounced 300ms via `restartable()`)
- Disposes file watcher on close

---

### 7. SidebarBloc

| | Detail |
|---|--------|
| **Purpose** | Sidebar tree data — branches, remotes, tags, stashes |

**Events:**
| Event | Payload |
|-------|---------|
| `LoadSidebarData` | — |
| `RefreshSidebar` | — |
| `ToggleSection` | `SidebarSection section` |
| `SelectItem` | `SidebarItem item` |
| `FilterItems` | `String query` |
| `ExpandRemote` | `String remoteName` |

**State:**
```
SidebarState {
  List<Branch> localBranches,
  Map<String, List<Branch>> remoteBranches,   // grouped by remote name
  List<Tag> tags,
  List<Stash> stashes,
  List<Submodule> submodules,
  Set<SidebarSection> expandedSections,
  SidebarItem? selectedItem,
  String filterQuery,
  bool isLoading,
}

enum SidebarSection { changes, branches, remotes, tags, stashes, submodules }
```

---

### 8. CommitGraphBloc

| | Detail |
|---|--------|
| **Purpose** | Commit history with DAG lane data — supports virtualized loading |

**Events:**
| Event | Payload |
|-------|---------|
| `LoadCommitHistory` | `String? branchFilter` |
| `LoadMoreCommits` | `int count` (default 100) |
| `SelectCommit` | `String sha` |
| `DeselectCommit` | — |
| `FilterByBranch` | `String? branchName` |
| `SearchCommits` | `String query` |
| `RefreshGraph` | — |
| `ToggleMergeCollapse` | `String sha` |

**State:**
```
CommitGraphState {
  List<GraphCommit> commits,       // loaded commits with lane info
  List<LaneDefinition> lanes,     // active lane definitions
  String? selectedCommitSha,
  String? branchFilter,
  String? searchQuery,
  bool isLoading,
  bool isLoadingMore,
  bool hasMoreCommits,
  int totalLoaded,
  Set<String> collapsedMerges,
}

GraphCommit {
  Commit commit,                   // base commit data
  int laneIndex,                   // which lane this commit is on
  List<GraphConnection> connections, // lines to draw
  List<BranchLabel> labels,        // branch/tag labels on this commit
  bool isHead,
}

GraphConnection {
  int fromLane,
  int toLane,
  ConnectionType type,             // straight, merge_left, merge_right, branch_left, branch_right
  int colorIndex,
}
```

**Event Transformers:**
- `LoadMoreCommits`: `droppable()` — prevent duplicate loads while loading
- `SearchCommits`: `restartable()` with 300ms debounce
- `RefreshGraph`: `restartable()`

---

### 9. CommitDetailBloc

| | Detail |
|---|--------|
| **Purpose** | Details of the selected commit — changed files list |

**Events:**
| Event | Payload |
|-------|---------|
| `LoadCommitDetail` | `String sha` |
| `SelectFile` | `String filePath` |
| `ClearDetail` | — |

**State:**
```
CommitDetailState {
  Commit? commit,
  List<FileChange> changedFiles,
  String? selectedFilePath,
  bool isLoading,
}
```

---

### 10. StagingBloc

| | Detail |
|---|--------|
| **Purpose** | Working copy staging area — unstaged and staged files |

**Events:**
| Event | Payload |
|-------|---------|
| `LoadWorkingCopy` | — |
| `RefreshWorkingCopy` | — |
| `StageFile` | `String path` |
| `UnstageFile` | `String path` |
| `StageAll` | — |
| `UnstageAll` | — |
| `StageHunk` | `String path, DiffHunk hunk` |
| `DiscardFile` | `String path` |
| `DiscardAll` | — |
| `SelectUnstagedFile` | `String path` |
| `SelectStagedFile` | `String path` |

**State:**
```
StagingState {
  List<FileStatus> unstagedFiles,
  List<FileStatus> stagedFiles,
  List<FileStatus> conflictedFiles,
  String? selectedFilePath,
  bool selectedIsStaged,
  bool isLoading,
  bool isStaging,                 // operation in progress
}
```

**Event Transformers:**
- `StageFile` / `UnstageFile`: `sequential()` — maintain ordering
- `RefreshWorkingCopy`: `restartable()`

---

### 11. CommitFormCubit

| | Detail |
|---|--------|
| **Purpose** | Commit message form state |

**State:**
```
CommitFormState {
  String message,
  String extendedMessage,
  bool isAmend,
  bool isSubmitting,
  bool canCommit,                 // message not empty && staged files exist
  String? error,
}
```

**Methods:**
- `updateMessage(String)`
- `updateExtendedMessage(String)`
- `toggleAmend()`
- `submit()` — creates commit via GitService
- `clear()`

---

### 12. DiffViewerBloc

| | Detail |
|---|--------|
| **Purpose** | Renders diff content for selected file |

**Events:**
| Event | Payload |
|-------|---------|
| `LoadDiff` | `String filePath, bool staged, String? commitSha` |
| `ToggleDiffMode` | `DiffMode mode` (unified / split) |
| `LoadImageDiff` | `String filePath` |
| `ClearDiff` | — |

**State:**
```
DiffViewerState {
  FileDiff? diff,
  DiffMode mode,                  // unified, split
  bool isLoading,
  bool isBinary,
  bool isImage,
  ImageDiffData? imageDiff,
}

enum DiffMode { unified, split }
```

---

### 13. BranchOperationBloc

| | Detail |
|---|--------|
| **Purpose** | Handles branch CRUD and merge/rebase operations |

**Events:**
| Event | Payload |
|-------|---------|
| `CreateBranch` | `String name, String? startPoint, bool checkout` |
| `DeleteBranch` | `String name, bool force` |
| `RenameBranch` | `String oldName, String newName` |
| `CheckoutBranch` | `String name` |
| `MergeBranch` | `String source, MergeStrategy? strategy` |
| `RebaseBranch` | `String upstream, String? onto` |
| `CherryPick` | `String sha` |
| `AbortMerge` | — |
| `AbortRebase` | — |
| `ContinueRebase` | — |

**State:**
```
BranchOperationState {
  bool isProcessing,
  OperationType? currentOperation,
  OperationResult? lastResult,
  String? error,
  MergeState? mergeState,        // in-progress merge info
  RebaseState? rebaseState,      // in-progress rebase info
}
```

---

### 14. RemoteOpsBloc

| | Detail |
|---|--------|
| **Purpose** | Push, pull, fetch operations with progress tracking |

**Events:**
| Event | Payload |
|-------|---------|
| `Fetch` | `String? remote` |
| `FetchAll` | — |
| `Pull` | `String? remote, PullMode mode` |
| `Push` | `String? remote, String? branch, bool force` |
| `SetUpstream` | `String remote, String branch` |
| `CancelOperation` | — |

**State:**
```
RemoteOpsState {
  bool isFetching,
  bool isPulling,
  bool isPushing,
  double? progress,               // 0.0–1.0
  String? progressMessage,
  String? error,
  DateTime? lastFetchTime,
}

enum PullMode { merge, rebase, fastForwardOnly }
```

**Event Transformers:**
- All events: `sequential()` — never run concurrent remote operations

---

### 15. StashBloc

**Events:** `LoadStashes`, `CreateStash(message?, includeUntracked?)`, `ApplyStash(index)`, `PopStash(index)`, `DropStash(index)`

**State:**
```
StashState {
  List<Stash> stashes,
  bool isProcessing,
  String? error,
}
```

---

### 16. SearchBloc

**Events:** `SearchCommits(query)`, `SearchFiles(query)`, `ClearSearch`

**State:**
```
SearchState {
  String query,
  SearchScope scope,              // commits, files, all
  List<SearchResult> results,
  bool isSearching,
}
```

**Event Transformer:** `restartable()` with 300ms debounce on search events

---

### 17. ConflictResolutionBloc

**Events:** `LoadConflicts`, `SelectConflictFile(path)`, `ChooseOurs(path)`, `ChooseTheirs(path)`, `MarkResolved(path)`, `AbortMerge`

**State:**
```
ConflictResolutionState {
  List<ConflictedFile> conflicts,
  String? selectedFilePath,
  Map<String, ConflictResolution> resolutions,
  bool allResolved,
}
```

---

## BLoC Communication Patterns

### Pattern 1: Sidebar → CommitGraph (branch selection)

```
SidebarBloc emits new selectedItem (branch)
  → BlocListener in RepositoryPage detects change
    → dispatches CommitGraphBloc.FilterByBranch(branchName)
```

### Pattern 2: CommitGraph → CommitDetail (commit selection)

```
CommitGraphBloc emits new selectedCommitSha
  → BlocListener dispatches CommitDetailBloc.LoadCommitDetail(sha)
```

### Pattern 3: CommitDetail → DiffViewer (file selection)

```
CommitDetailBloc emits new selectedFilePath
  → BlocListener dispatches DiffViewerBloc.LoadDiff(path, sha)
```

### Pattern 4: RepositoryBloc → All child blocs (refresh)

```
RepositoryBloc emits RepositoryLoaded (after file watcher triggers refresh)
  → BlocListener dispatches:
    - SidebarBloc.RefreshSidebar
    - CommitGraphBloc.RefreshGraph
    - StagingBloc.RefreshWorkingCopy
```

### Pattern 5: BranchOperationBloc → RepositoryBloc (after branch op)

```
BranchOperationBloc completes a checkout/merge/rebase
  → BlocListener dispatches RepositoryBloc.RefreshRepository
```

---

## Event Transformer Summary

| Bloc | Event | Transformer | Rationale |
|------|-------|-------------|-----------|
| CommitGraphBloc | LoadMoreCommits | `droppable()` | Prevent duplicate pagination |
| CommitGraphBloc | SearchCommits | `restartable()` + debounce | Cancel previous search on new input |
| CommitGraphBloc | RefreshGraph | `restartable()` | Only latest refresh matters |
| StagingBloc | StageFile/UnstageFile | `sequential()` | Maintain operation order |
| StagingBloc | RefreshWorkingCopy | `restartable()` | Only latest refresh matters |
| RemoteOpsBloc | All events | `sequential()` | No concurrent remote ops |
| SearchBloc | SearchCommits | `restartable()` + debounce | Cancel previous search |
| RepositoryBloc | RefreshRepository | `restartable()` | Debounced file watcher |
