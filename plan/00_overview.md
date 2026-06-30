# 00 — Project Overview & Architecture

## Project Name: **Furcate** (Git Client)

A pixel-accurate clone of the [Branched Git Client](https://github.com/azimuthdeveloper/branched.git) Git client, built with Flutter for **macOS**, **Linux**, and **Windows** desktop platforms.

---

## Goals

| # | Goal | Notes |
|---|------|-------|
| 1 | Visual fidelity to Branched | Sidebar, commit graph, diff viewer, tab bar, context menus |
| 2 | Cross-platform desktop | macOS, Linux, Windows — single codebase |
| 3 | Strict BLoC state management | No `setState` anywhere; `flutter_bloc` + `equatable` |
| 4 | Native Git via `git2dart` | libgit2 bindings — no dependency on system `git` CLI |
| 5 | Production-quality architecture | Clean Architecture, feature-first folders, DI via `get_it` |

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Framework** | Flutter 3.x (stable) | Cross-platform desktop UI |
| **State** | `flutter_bloc`, `bloc`, `equatable` | All state management — zero `setState` |
| **Git Engine** | `git2dart` (libgit2 bindings) | Repository operations, auth, diffing |
| **DI** | `get_it` + `injectable` | Service locator / dependency injection |
| **Persistence** | `hydrated_bloc`, `hive` | App settings, recent repos, preferences |
| **Code Gen** | `freezed`, `json_serializable` | Immutable state classes & models |
| **Window** | `bitsdojo_window` | Custom title bar, window controls |
| **Routing** | In-app tab router (custom) | Multi-tab repository management |
| **Platform** | `macos_window_utils` (macOS extras) | Traffic lights, vibrancy |
| **Testing** | `bloc_test`, `mocktail`, integration | Full coverage strategy |

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────────┐   │
│  │  Widgets  │  │  Pages   │  │  BLoCs   │  │  Cubits       │   │
│  └──────────┘  └──────────┘  └──────────┘  └───────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                         Domain Layer                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────────────────┐  │
│  │ Entities  │  │Use Cases │  │  Repository Interfaces       │  │
│  └──────────┘  └──────────┘  └──────────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                          Data Layer                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │ Git Data Source  │  │ Local Storage   │  │ Repo Impls     │  │
│  │ (git2dart)       │  │ (Hive/Prefs)    │  │                │  │
│  └─────────────────┘  └─────────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Folder Structure

```
lib/
├── main.dart                          # App entry point
├── app.dart                           # MaterialApp / root widget
├── injection.dart                     # get_it setup
│
├── core/
│   ├── theme/                         # Branched-style dark/light themes
│   ├── constants/                     # Colors, spacing, font sizes
│   ├── extensions/                    # Dart/Flutter extension methods
│   ├── error/                         # Failure classes, exceptions
│   ├── platform/                      # Platform detection helpers
│   └── widgets/                       # Shared reusable widgets
│
├── features/
│   ├── window_chrome/                 # Custom title bar, tabs, window buttons
│   ├── sidebar/                       # Repository tree: branches, tags, remotes, stashes
│   ├── commit_graph/                  # DAG visualization, commit list
│   ├── staging/                       # Working directory changes, staging area
│   ├── diff_viewer/                   # Side-by-side & unified diff
│   ├── commit_detail/                 # Selected commit info, changed files
│   ├── branching/                     # Create, rename, delete, checkout branches
│   ├── merging/                       # Merge, rebase, cherry-pick, conflict resolution
│   ├── remote_ops/                    # Push, pull, fetch, clone
│   ├── authentication/                # SSH keys, HTTPS creds, credential storage
│   ├── stash/                         # Stash create, apply, pop, drop
│   ├── tags/                          # Tag management
│   ├── search/                        # Commit search, file search, branch filter
│   ├── settings/                      # App preferences, git config
│   ├── repository_manager/            # Open, clone, init, recent repos
│   ├── git_flow/                      # Git-Flow operations
│   └── interactive_rebase/            # Visual interactive rebase
│
└── git_engine/                        # Abstraction layer over git2dart
    ├── git_service.dart               # High-level API surface
    ├── git_auth_handler.dart          # Credentials & auth callbacks
    ├── git_diff_parser.dart           # Diff result transformation
    ├── git_graph_builder.dart         # DAG → lane model conversion
    └── models/                        # Git-specific data models
```

---

## Plan Documents Index

| File | Component |
|------|-----------|
| `01_project_setup.md` | Project initialization, dependencies, build configuration |
| `02_ui_design.md` | Branched UI replication — layout, theme, typography, colors |
| `03_state_management.md` | BLoC architecture — all blocs, events, states |
| `04_git_engine.md` | git2dart integration — abstraction layer, operations |
| `05_repository_management.md` | Open, clone, init, recent repos, multi-tab |
| `06_commit_graph.md` | DAG visualization — lane rendering, commit list |
| `07_branching_merging.md` | Branch CRUD, merge, rebase, cherry-pick, conflicts |
| `08_staging_committing.md` | Working tree changes, staging, commit workflow |
| `09_diff_viewer.md` | Side-by-side / unified diff, image diff, syntax highlight |
| `10_remote_operations.md` | Push, pull, fetch, clone, remote management |
| `11_authentication.md` | SSH, HTTPS, credential storage, ssh-agent |
| `12_sidebar.md` | Sidebar tree — branches, tags, remotes, stashes, submodules |
| `13_search_filtering.md` | Commit search, file search, branch filter |
| `14_settings_configuration.md` | App settings, git config, keyboard shortcuts |
| `15_platform_integration.md` | macOS / Linux / Windows — native menus, window chrome |
| `16_testing_strategy.md` | Unit, widget, integration, golden tests |
| `17_milestones.md` | Phased delivery roadmap with milestones |

---

## Design Principles

1. **Zero `setState`** — All mutable state flows through `Bloc` or `Cubit`. Even ephemeral UI state uses a Cubit.
2. **Feature-first** — Each feature is a self-contained module with its own data/domain/presentation layers.
3. **Repository pattern** — Domain layer defines interfaces; data layer implements them via `git2dart` or local storage.
4. **Immutable states** — All BLoC states use `freezed` for immutability and `equatable` for comparison.
5. **Platform-adaptive** — One codebase, but platform-aware widgets for native feel on each OS.
6. **Performance-first** — Lazy-loading commit history, virtualized lists, isolate-based git operations for heavy tasks.
