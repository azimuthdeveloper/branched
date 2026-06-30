# 05 — Repository Management

## Overview

Repository management covers the full lifecycle of interacting with Git repositories: opening existing repos, cloning from remotes, initializing new repos, managing recent repos, and the multi-tab system that lets users work on multiple repos simultaneously.

---

## Welcome Screen (No Repos Open)

When no repositories are open, display a welcome/start screen:

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│                    🔀 Furcate                        │
│                                                      │
│     [ Open Repository ]   [ Clone Repository ]       │
│     [ Init Repository ]                              │
│                                                      │
│     ─── Recent Repositories ───                      │
│                                                      │
│     📁 my-project          ~/code/my-project         │
│     📁 flutter-app         ~/code/flutter-app        │
│     📁 api-server          ~/work/api-server         │
│     📁 dotfiles            ~/.dotfiles               │
│                                                      │
│     [ Clear Recent ]                                 │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### Welcome Screen Features

| Feature | Description |
|---------|-------------|
| Open Repository | Opens native directory picker dialog |
| Clone Repository | Opens clone dialog (URL + destination) |
| Init Repository | Opens directory picker, creates new repo |
| Recent Repositories | Clickable list, sorted by last opened |
| Pin/Unpin | Star icon to pin repos to top of recent list |
| Remove from recent | X button on hover, or right-click → Remove |
| Drag & Drop | Drag a folder onto the window to open it |

---

## Open Repository Flow

```
User clicks "Open Repository"
  → Native file picker dialog (directory mode)
  → User selects a directory
  → GitService.isGitRepository(path)
    → If true:  RepositoryManagerBloc.OpenRepository(path)
    → If false: Show error "Not a Git repository"
                Offer to initialize: "Initialize a repository here?"
  → RecentRepositoriesCubit.addRecent(path)
  → New tab created
  → RepositoryBloc.LoadRepository(path)
```

### Validation Checks

- Path exists on disk
- Path is a directory (not a file)
- Path contains a `.git` directory (or is a bare repo)
- Path is not already open in another tab (switch to that tab instead)

---

## Clone Repository Flow

### Clone Dialog

```
┌─────────────────────────────────────────────────┐
│  Clone Repository                          [✕]  │
├─────────────────────────────────────────────────┤
│                                                  │
│  Repository URL:                                │
│  ┌──────────────────────────────────────────┐   │
│  │ https://github.com/user/repo.git          │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  Clone to:                                      │
│  ┌──────────────────────────────────┐ [Browse]  │
│  │ /home/user/code/repo             │           │
│  └──────────────────────────────────┘           │
│                                                  │
│  Name: repo (auto-filled from URL)              │
│                                                  │
│  [ ] Recurse submodules                         │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │ ░░░░░░░░░░░░░░░░░░░░░░░░  45%           │   │  ← Progress bar
│  │ Receiving objects: 450/1000               │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│                    [ Cancel ]  [ Clone ]         │
└─────────────────────────────────────────────────┘
```

### Clone Flow

```
1. User enters URL
2. Auto-detect repo name from URL, fill destination path
3. User clicks Clone
4. GitService.cloneRepository(url, path, credentials, onProgress)
   → Runs in isolate
   → Progress reported via callback
   → On auth failure: prompt for credentials (see 11_authentication.md)
5. On success:
   → RepositoryManagerBloc.OpenRepository(path)
   → RecentRepositoriesCubit.addRecent(path)
6. On failure:
   → Show error in dialog
   → Clean up partially cloned directory
```

---

## Init Repository Flow

```
1. User clicks "Init Repository"
2. Native directory picker (or text input)
3. GitService.initRepository(path)
4. Options dialog:
   - [x] Create initial commit
   - [ ] Bare repository
   - Default branch name: main
5. On success: open in new tab
```

---

## Multi-Tab System

### Tab Bar Design

```
[ ● repo-a ][ repo-b ][ repo-c (●) ][ + ]
```

| Element | Behavior |
|---------|----------|
| Tab label | Repository folder name |
| Dirty indicator | Small dot (●) when uncommitted changes exist |
| Close button | "×" appears on hover, click to close tab |
| Active tab | Lighter background, visible bottom border |
| "+" button | Opens repository picker |
| Tab reordering | Drag and drop to reorder |
| Middle-click | Close tab |
| Tab overflow | Scroll with arrow buttons when too many tabs |
| Max tabs | No hard limit, scroll horizontally |

### Tab State Management

Each tab maintains its own independent BLoC tree:

```
Tab 1 (repo-a)                    Tab 2 (repo-b)
├── RepositoryBloc                 ├── RepositoryBloc
├── SidebarBloc                    ├── SidebarBloc
├── CommitGraphBloc                ├── CommitGraphBloc
├── StagingBloc                    ├── StagingBloc
├── DiffViewerBloc                 ├── DiffViewerBloc
└── ...                            └── ...
```

- Switching tabs swaps the entire BLoC tree
- Inactive tabs remain alive (blocs not disposed until tab is closed)
- File watchers remain active on all open tabs (background refresh)
- Memory consideration: for tabs not visible, defer heavy refreshes

### Tab Lifecycle

```
Open Tab:
  1. Create new RepoTab entry in RepositoryManagerBloc
  2. Create BLoC tree for this tab
  3. RepositoryBloc.LoadRepository(path)
  4. Start file watcher

Switch Tab:
  1. RepositoryManagerBloc.SwitchTab(index)
  2. Swap BlocProviders in widget tree
  3. No reload needed (blocs still have state)

Close Tab:
  1. Confirm if dirty (unsaved changes dialog)
  2. Stop file watcher
  3. Dispose all blocs for this tab
  4. GitService.disposeRepository(repo)
  5. Remove tab from RepositoryManagerBloc
  6. If last tab closed, show welcome screen
```

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + O` | Open repository |
| `Cmd/Ctrl + Shift + N` | Clone repository |
| `Cmd/Ctrl + W` | Close current tab |
| `Cmd/Ctrl + Tab` | Next tab |
| `Cmd/Ctrl + Shift + Tab` | Previous tab |
| `Cmd/Ctrl + 1–9` | Switch to tab N |
| `Cmd/Ctrl + Shift + T` | Reopen last closed tab |

---

## Drag & Drop Support

- Drag a folder from file manager onto the app window
- Validate it's a git repository
- Open in a new tab
- Use `DropTarget` widget wrapping the entire window

---

## Repository Info Cache

Cache basic info for recently opened repos to speed up the welcome screen:

```
RepoCacheEntry {
  String path,
  String name,
  String? currentBranch,
  int? uncommittedCount,
  DateTime lastOpened,
  DateTime lastCached,
  bool pinned,
}
```

- Update cache when opening/closing repos
- Stale cache entries (repo no longer exists) are removed on startup
- Store in Hive box: `recent_repositories`
