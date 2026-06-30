# 17 — Milestones & Roadmap

## Overview

The development is broken into 6 milestones, each building on the previous. Each milestone produces a usable (if incomplete) application.

---

## Milestone 1: Foundation & Shell (Weeks 1–3)

### Goal
Empty app shell with window chrome, theme system, and git engine connected.

### Deliverables

| Component | Tasks |
|-----------|-------|
| **Project Setup** | Flutter project, all dependencies, folder structure, build_runner, lint |
| **Window Chrome** | Custom title bar with tabs (empty), window buttons per platform |
| **Theme System** | Dark + Light themes, FurcateColors extension, platform fonts |
| **DI Container** | get_it + injectable setup, all services registered |
| **Git Engine** | GitService interface + implementation with git2dart |
| **Repository Open** | Open a repository, read basic info (current branch, HEAD) |
| **App Shell** | Sidebar (empty) + main content area (empty) + toolbar (disabled buttons) |
| **Panel Layout** | Resizable sidebar, persisted widths |

### Exit Criteria
- App launches on all 3 platforms
- Can open a git repository via file picker
- Title bar shows repo name in a tab
- Theme toggles between dark/light
- git2dart successfully reads branch and HEAD info

---

## Milestone 2: Sidebar & Commit Graph (Weeks 4–7)

### Goal
Browse repository history — sidebar tree + scrollable commit graph with DAG visualization.

### Deliverables

| Component | Tasks |
|-----------|-------|
| **Sidebar** | Full tree: branches, remotes, tags, stashes with expand/collapse |
| **Sidebar Filter** | Search input filters tree items |
| **Commit Graph** | DAG lane algorithm + CustomPainter rendering |
| **Commit List** | Scrollable list with columns: graph, message, author, date, SHA |
| **Virtualization** | Paginated loading (100 commits per page), scroll-to-load-more |
| **Commit Selection** | Click commit → load detail in bottom panel |
| **Branch Labels** | Inline badges on commits for branches and tags |
| **Branch Checkout** | Double-click branch in sidebar to checkout |
| **BLoCs** | RepositoryBloc, SidebarBloc, CommitGraphBloc, CommitDetailBloc |

### Exit Criteria
- Sidebar shows all branches, remotes, tags, stashes
- Commit graph renders with colored lanes and merge connections
- Scrolling through 1000+ commits is smooth (60fps)
- Clicking a commit shows changed files in bottom panel
- Can checkout branches from sidebar

---

## Milestone 3: Working Copy & Staging (Weeks 8–11)

### Goal
Full working copy management — stage, unstage, diff preview, commit.

### Deliverables

| Component | Tasks |
|-----------|-------|
| **Working Copy View** | Unstaged + staged file lists |
| **File Status** | Correct icons/colors for M/A/D/R/? status |
| **Stage/Unstage** | File-level stage/unstage, stage all, unstage all |
| **Diff Viewer** | Unified diff with syntax highlighting |
| **Split Diff** | Side-by-side diff mode with synchronized scrolling |
| **Hunk Staging** | Stage individual hunks |
| **Commit Form** | Summary + description, amend toggle, commit button |
| **Commit Flow** | Create commit, refresh graph, clear form |
| **Discard** | Discard file changes with confirmation |
| **File Watcher** | Auto-refresh on file system changes (debounced) |
| **BLoCs** | StagingBloc, CommitFormCubit, DiffViewerBloc |

### Exit Criteria
- Can see all file changes in working copy
- Stage/unstage files and hunks
- Diff viewer shows changes with syntax highlighting
- Can write commit message and create commits
- Working copy auto-refreshes when files change

---

## Milestone 4: Remote Operations & Auth (Weeks 12–15)

### Goal
Full remote workflow — fetch, pull, push with authentication.

### Deliverables

| Component | Tasks |
|-----------|-------|
| **Fetch** | Fetch from remote with progress bar |
| **Pull** | Pull (merge, rebase, ff-only modes) |
| **Push** | Push with upstream setup dialog |
| **Clone** | Clone dialog with URL, destination, progress |
| **Auth (HTTPS)** | Username/password prompt, PAT support |
| **Auth (SSH)** | SSH key detection, passphrase prompt, ssh-agent |
| **Credential Storage** | Save to OS keychain, retrieve on next use |
| **Progress UI** | Toolbar progress bar for all remote ops |
| **Error Handling** | Network errors, auth failures, push rejection |
| **Force Push** | Confirmation dialog |
| **Remote Management** | Add/edit/remove remotes |
| **BLoCs** | RemoteOpsBloc, enhanced RepositoryManagerBloc (clone) |

### Exit Criteria
- Can clone a repo from HTTPS and SSH URLs
- Fetch/pull/push work with progress indication
- Credentials are prompted and saved securely
- Auth works on all 3 platforms
- Push rejection offers pull-first option

---

## Milestone 5: Branch Ops & Conflict Resolution (Weeks 16–19)

### Goal
Advanced branch operations — merge, rebase, cherry-pick, conflict resolution.

### Deliverables

| Component | Tasks |
|-----------|-------|
| **Create Branch** | Dialog with name, base, checkout option |
| **Delete Branch** | Confirmation, force delete option |
| **Rename Branch** | Inline rename or dialog |
| **Merge** | Merge dialog with strategy selection |
| **Rebase** | Rebase dialog with upstream selection |
| **Cherry-Pick** | From commit context menu |
| **Conflict Resolution** | Conflict mode UI, per-file resolution |
| **Three-Way Diff** | Side-by-side ours/theirs/base view |
| **Merge Abort/Continue** | Persistent banner during merge/rebase |
| **Reset** | Soft/mixed/hard reset dialog |
| **Stash** | Create, apply, pop, drop from sidebar |
| **Tag Management** | Create/delete tags |
| **Context Menus** | Full context menus on branches, commits, files |
| **BLoCs** | BranchOperationBloc, ConflictResolutionBloc, StashBloc, TagBloc |

### Exit Criteria
- Can create/delete/rename branches
- Merge and rebase with conflict resolution
- Cherry-pick from commit context menu
- Stash operations work from sidebar
- All context menus functional

---

## Milestone 6: Polish & Advanced Features (Weeks 20–24)

### Goal
Production-ready quality — search, settings, interactive rebase, performance, distribution.

### Deliverables

| Component | Tasks |
|-----------|-------|
| **Search** | Commit search, file filter, find-in-diff |
| **Command Palette** | Quick open (Cmd+P), command palette (Cmd+Shift+P) |
| **Settings** | Full settings window with all categories |
| **Keyboard Shortcuts** | All shortcuts implemented, customization UI |
| **Interactive Rebase** | Visual rebase editor (CLI fallback) |
| **Git-Flow** | Git-Flow operations (feature, release, hotfix) |
| **Image Diff** | Side-by-side, swipe, onion skin for images |
| **Command Log** | Show equivalent git commands |
| **Native Menus** | macOS application menu bar |
| **Drag & Drop** | Drag folders to open, drag branches to merge |
| **Welcome Screen** | Polish with recent repos, pinning |
| **Performance** | Optimize large repos, profile and fix bottlenecks |
| **Golden Tests** | Full golden test suite |
| **Integration Tests** | Critical path integration tests |
| **Packaging** | DMG, AppImage/deb, MSIX/exe packaging |
| **Code Signing** | macOS notarization, Windows signing |

### Exit Criteria
- App is feature-complete matching Branched's core functionality
- Performance targets met (see 16_testing_strategy.md)
- All tests passing on all platforms
- Packaged installers for all platforms
- Ready for beta release

---

## Timeline Summary

```
Week  1─3   ████████░░░░░░░░░░░░░░░░  M1: Foundation & Shell
Week  4─7   ░░░░████████████░░░░░░░░  M2: Sidebar & Commit Graph
Week  8─11  ░░░░░░░░░░░░████████████  M3: Working Copy & Staging
Week 12─15  ████████████░░░░░░░░░░░░  M4: Remote Ops & Auth
Week 16─19  ░░░░░░░░░░░░████████████  M5: Branch Ops & Conflicts
Week 20─24  ████████████████████████  M6: Polish & Advanced
```

**Total: ~24 weeks (6 months) for a single developer**

Scale linearly with team size:
- 2 developers: ~14 weeks
- 3 developers: ~10 weeks

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| git2dart missing features | Medium | High | CLI fallback adapter ready |
| Graph algorithm performance on huge repos | Medium | Medium | Profiling early, isolate computation |
| Platform-specific window bugs | High | Medium | Test on all platforms continuously |
| SSH auth complexity per platform | Medium | High | Start with HTTPS, iterate SSH |
| Flutter desktop rendering performance | Low | High | CustomPainter optimization, profiling |
| libgit2 native library bundling | Medium | Medium | Test distribution early in M1 |
| Conflict resolution edge cases | Medium | Medium | Extensive test fixtures |

---

## Definition of Done (per feature)

- [ ] Implementation complete
- [ ] Unit tests written and passing
- [ ] BLoC tests written and passing
- [ ] Widget tests for new UI components
- [ ] No lint warnings
- [ ] Documentation updated (if public API)
- [ ] Tested on macOS, Linux, and Windows
- [ ] PR reviewed (if team > 1)
