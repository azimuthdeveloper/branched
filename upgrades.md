# Branched — Production Readiness Upgrades

> A comprehensive gap analysis and upgrade plan for transforming the current prototype into a
> production-ready desktop Git client with feature parity to Fork, GitKraken, and Tower.

---

## 🔴 P0 — Critical Bugs (Fix Immediately)

### 1. ScrollController Conflict in Commit Graph

**File:** `lib/features/commit_graph/commit_graph.dart`

The same `_scrollController` is assigned to both a `SingleChildScrollView` (wrapping the
`CustomPaint` graph) and the `ListView.builder` for the text columns. Flutter does not allow a
single `ScrollController` to be attached to multiple scrollable widgets simultaneously and will
throw assertion errors.

**Fix:** Use two separate controllers and synchronize them via `NotificationListener<ScrollNotification>`
on the `ListView`, forwarding the scroll offset to the `CustomPaint` wrapper's controller with
`jumpTo()`.

---

### 2. macOS Release Entitlements Are Incomplete

**File:** `macos/Runner/Release.entitlements`

The release build is missing `com.apple.security.network.client` (needed for HTTPS fetch/push/pull),
`com.apple.security.network.server`, and `com.apple.security.cs.allow-jit` — all of which are
present in `DebugProfile.entitlements`. This means **release builds will fail to make any network
Git requests**.

**Fix:** Mirror all required entitlements from `DebugProfile.entitlements` into `Release.entitlements`.
Add hardened runtime entitlements for notarized distribution outside the Mac App Store.

---

### 3. `getCommitHistory()` Ignores `branch` Parameter

**File:** `lib/git_engine/git_service_impl.dart` (line ~301)

The `branch` parameter on `getCommitHistory()` is accepted but never appended to the `git log`
argument list because `--all` was unconditionally added. Branch-specific history filtering is
completely broken.

**Fix:** When a `branch` parameter is provided, omit `--all` and append the branch name to the
args list. Only use `--all` when `branch` is null.

---

### 4. `getCommit()` Is Broken

**File:** `lib/git_engine/git_service_impl.dart`

`getCommit(repo, sha)` calls `getCommitHistory(repo, limit: 1, branch: sha)` but because the
`branch` parameter is ignored (see bug #3), it never returns the requested commit.

**Fix:** Use `git log -1 --format=... <sha>` directly.

---

### 5. Process Encoding Is Not Cross-Platform

**File:** `lib/git_engine/git_service_impl.dart` (line ~38)

`_run()` uses `systemEncoding` for stdout/stderr. On Windows, `systemEncoding` is often CP-1252,
which will corrupt non-ASCII filenames, commit messages, and diff content.

**Fix:** Use `utf8` encoding explicitly. Ensure all git commands also include `-c core.quotepath=false`
to prevent Git from escaping non-ASCII filenames.

---

### 6. `discardAll` Is Dangerously Unguarded

**File:** `lib/git_engine/git_service_impl.dart`

`discardAll` runs `git clean -fd` which permanently deletes all untracked files and directories
with no confirmation and no dry-run preview.

**Fix:** Add a `discardAllPreview()` method that runs `git clean -fdn` first to show what would
be deleted. Require confirmation in the UI before executing the real clean.

---

## 🔴 P0 — Critical Missing Features

### 7. SSH Authentication

**Current:** Only inline HTTPS credentials (`username:password` embedded in URL), which is
insecure and visible in process lists.

**Required:**
- SSH key management UI (list, add, remove keys from `~/.ssh/`)
- SSH agent integration (`ssh-agent`, macOS Keychain, Windows OpenSSH agent)
- SSH passphrase prompting via dialog
- Support for SSH URLs (`git@github.com:user/repo.git`)
- Automatic detection of URL scheme (HTTPS vs SSH) when cloning

**Files to change:**
- `git_service.dart` — Add `SshCredential`, `HttpsCredential` types
- `git_service_impl.dart` — Pass `GIT_SSH_COMMAND` env var for custom key paths
- `welcome_screen.dart` — Add SSH URL support to clone dialog
- New: `lib/core/credential_manager.dart`
- New: `lib/features/settings/credentials_panel.dart`

---

### 8. Hosting Provider Integration (GitHub, Azure DevOps, Bitbucket, GitLab)

**Current:** Clone dialog only accepts a raw URL. No account linking, no repo browsing, no
PR integration.

**Required — Phase 1 (Clone & Auth):**
- OAuth2 / PAT (Personal Access Token) authentication for each provider
- Account manager UI: add/remove linked accounts
- Repository browser: list user's repos from each provider, search, clone with one click
- Automatic credential helper configuration per provider
- SSH key upload to provider from within the app

**Required — Phase 2 (Pull Request Integration):**
- View open PRs / merge requests in sidebar
- Create PR from current branch (opens dialog with title, description, reviewers)
- PR status badges on branches (approved, changes requested, CI status)
- Quick links to open PR in browser

**Provider-specific API clients needed:**

| Provider | Auth Method | API Base | Key Endpoints |
|----------|-------------|----------|---------------|
| GitHub | OAuth2 / PAT | `api.github.com` | `/user/repos`, `/repos/:owner/:repo/pulls` |
| Azure DevOps | PAT / OAuth2 | `dev.azure.com` | `/_apis/git/repositories`, `/_apis/git/pullrequests` |
| Bitbucket | App Password / OAuth2 | `api.bitbucket.org/2.0` | `/repositories/:workspace`, `/pullrequests` |
| GitLab | PAT / OAuth2 | `gitlab.com/api/v4` | `/projects`, `/merge_requests` |

**New files:**
- `lib/core/hosting/hosting_provider.dart` — Abstract interface
- `lib/core/hosting/github_provider.dart`
- `lib/core/hosting/azure_devops_provider.dart`
- `lib/core/hosting/bitbucket_provider.dart`
- `lib/core/hosting/gitlab_provider.dart`
- `lib/core/credential_manager.dart` — Secure credential storage (keychain/credential store)
- `lib/features/accounts/accounts_panel.dart` — Account management UI
- `lib/features/clone/clone_browser_screen.dart` — Repo browser for cloning
- `lib/features/pull_requests/pr_panel.dart` — PR list and creation

**Dependencies to add:** `http`, `url_launcher`, `flutter_secure_storage`

---

### 9. Rebase Support

**Current:** Completely absent from interface, implementation, and UI.

**Required:**
- Standard rebase: `git rebase <branch>`
- Interactive rebase: `git rebase -i <commit>` with pick/squash/fixup/edit/drop editor
- Continue / Skip / Abort during rebase-in-progress
- Rebase status detection in repo state
- UI: Context menu on branches → "Rebase onto..." and on commits → "Interactive rebase from here"

**Files to change:**
- `git_service.dart` — Add `rebase()`, `interactiveRebase()`, `continueRebase()`, `abortRebase()`, `getRebaseStatus()`
- `git_service_impl.dart` — Implement using `git rebase` commands
- `git_models.dart` — Add `RebaseStatus`, `RebaseTodoEntry` models
- `sidebar.dart` — Add rebase context menu on branches
- `commit_graph.dart` — Add context menu on commits
- New: `lib/features/rebase/interactive_rebase_panel.dart`
- New: `lib/features/rebase/rebase_bloc.dart`

---

### 10. Cherry-Pick, Reset, and Revert

**Current:** All three are completely absent.

**Required:**
- Cherry-pick: `git cherry-pick <sha>` with conflict handling
- Reset: `git reset --soft|--mixed|--hard <sha>` with confirmation for hard reset
- Revert: `git revert <sha>` with conflict handling
- All three should be accessible from commit context menus in the graph

**Files to change:**
- `git_service.dart` — Add `cherryPick()`, `reset()`, `revertCommit()`
- `git_service_impl.dart` — Implement
- `commit_graph.dart` — Add commit context menu
- New: `lib/features/reset/reset_dialog.dart` (mode selector + confirmation)

---

### 11. Merge Conflict Resolution UI

**Current:** Status parsing detects conflicted files (UU, AA, DD, AU, UA) but there is no UI
to resolve them.

**Required:**
- Conflict list panel showing all conflicted files
- Per-file resolution options: Accept Ours / Accept Theirs / Accept Both / Manual Edit
- 3-way merge editor: Base | Ours | Theirs with inline conflict markers
- "Mark as Resolved" button (runs `git add <file>`)
- "Abort Merge" button prominently displayed during merge state
- Detect and display merge/rebase/cherry-pick in-progress state in toolbar

**New files:**
- `lib/features/conflict/conflict_panel.dart`
- `lib/features/conflict/conflict_bloc.dart`
- `lib/features/conflict/three_way_merge_editor.dart`

---

### 12. Split Diff View

**File:** `lib/features/diff_viewer/diff_panel.dart`

The Unified/Split toggle buttons exist but the renderer always uses unified mode. The split
(side-by-side) view is not implemented.

**Fix:** Implement a two-column `Row` layout with synchronized vertical scrolling, pairing old
and new lines on matching rows. Need line-alignment logic to handle added/removed line offsets.

---

### 13. Syntax Highlighting in Diff Viewer

**File:** `lib/features/diff_viewer/diff_panel.dart`

The `re_highlight` package is listed as a dependency but completely unused. All diff content
renders as plain monochrome text.

**Fix:** Detect file language from extension, apply `re_highlight` tokenization to line content,
and render with colored `TextSpan` widgets instead of plain `Text`.

---

## 🟠 P1 — High Priority (Fork Feature Parity)

### 14. Submodule UI and Management

**Current:** Submodules are completely invisible in the app. No detection, no listing, no
operations.

**Required:**
- **Detection:** On repository open, run `git submodule status` to detect submodules
- **Sidebar section:** New collapsible "Submodules" section between Branches and Tags showing
  each submodule with its current commit SHA, path, and sync status
- **Status indicators per submodule:**
  - ✅ Clean (submodule at expected commit)
  - ⚠️ Modified (submodule HEAD differs from recorded commit)
  - ❌ Uninitialized (submodule not yet cloned)
  - 🔄 Out of date (remote has newer commits)
- **Submodule operations:**
  - Init (`git submodule init`)
  - Update (`git submodule update --init --recursive`)
  - Sync (`git submodule sync`)
  - Add submodule (dialog: URL + path)
  - Remove submodule
  - Open submodule as separate tab (treating it as its own repo)
- **Diff integration:** When a submodule pointer changes, show the old→new commit SHA in the
  staging panel instead of a binary diff
- **Recursive support:** Handle nested submodules (submodule within a submodule)

**New files:**
- `git_service.dart` — Add `getSubmodules()`, `initSubmodules()`, `updateSubmodules()`, `syncSubmodules()`, `addSubmodule()`, `removeSubmodule()`
- `git_service_impl.dart` — Implement using `git submodule` commands
- `git_models.dart` — Add `SubmoduleEntity` model (name, path, url, sha, status, isInitialized)
- `lib/features/sidebar/sidebar.dart` — Add Submodules section
- `lib/features/sidebar/sidebar_bloc.dart` — Load submodule data
- New: `lib/features/submodules/submodule_panel.dart` — Detailed submodule status view
- New: `lib/features/submodules/submodule_bloc.dart`

---

### 15. Context Menus Throughout the App

**Current:** No right-click context menus anywhere in the application.

**Required:**

| Location | Menu Items |
|----------|------------|
| Branch (sidebar) | Checkout, Merge into current, Rebase onto, Delete, Rename, Push, Copy name |
| Remote branch (sidebar) | Checkout as local, Fetch, Delete remote branch, Copy name |
| Tag (sidebar) | Checkout, Delete, Push, Copy name |
| Stash (sidebar) | Apply, Pop, Drop, View diff |
| Commit (graph) | Cherry-pick, Revert, Reset to here, Create branch, Create tag, Copy SHA, Browse files |
| Staged file (staging) | Unstage, Diff, Open in editor |
| Unstaged file (staging) | Stage, Discard changes, Diff, Open in editor, Add to .gitignore |
| Diff hunk (diff viewer) | Stage hunk, Discard hunk, Copy |
| Tab (window chrome) | Close, Close others, Close all, Copy path |

---

### 16. Keyboard Shortcuts

**Current:** No keyboard shortcuts at all.

**Required:**

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl+O` | Open repository |
| `Cmd/Ctrl+N` | Init new repository |
| `Cmd/Ctrl+Shift+O` | Clone repository |
| `Cmd/Ctrl+1-9` | Switch tabs |
| `Cmd/Ctrl+W` | Close current tab |
| `Cmd/Ctrl+Shift+A` | Stage all |
| `Cmd/Ctrl+Enter` | Commit |
| `Cmd/Ctrl+Shift+P` | Push |
| `Cmd/Ctrl+Shift+F` | Fetch |
| `Cmd/Ctrl+Shift+L` | Pull |
| `Cmd/Ctrl+K` | Search commits |
| `Cmd/Ctrl+B` | Create branch |
| `Cmd/Ctrl+,` | Settings |
| `F5` | Refresh |
| `Escape` | Clear selection / Close dialog |

**Implementation:** Use Flutter's `Shortcuts` + `Actions` widgets at the app level, with a
`KeyboardShortcutService` registered in the locator for customization persistence.

---

### 17. Blame View

**Current:** Completely absent.

**Required:**
- `git blame --porcelain <file>` parsing in `RealGitService`
- Dedicated blame panel with: line numbers, commit SHA per line, author per line, date per line
- Color-coded by commit age (recent = brighter, old = dimmer)
- Click on blame annotation to jump to that commit in the graph
- Accessible from file context menu and diff viewer toolbar

---

### 18. File History View

**Current:** Completely absent.

**Required:**
- `git log --follow -- <path>` for per-file commit history
- Dedicated panel showing commit list filtered to a single file
- Click commit to see that file's diff at that point
- Accessible from staging panel file context menu and diff viewer toolbar

---

### 19. Partial (Hunk) Staging

**Current:** Can only stage/unstage entire files.

**Required:**
- Parse diff output into individual hunks
- In the diff viewer gutter, show Stage/Unstage buttons per hunk
- Optionally support line-level staging (`git add -p` with patch construction)
- Update staging panel to refresh after hunk operations

---

### 20. Settings / Preferences UI

**Current:** No settings screen at all.

**Required settings:**
- **General:** Default clone directory, auto-fetch interval, date format, language
- **Git config:** `user.name`, `user.email` (global and per-repo)
- **Appearance:** Theme (dark/light/system), font family, font size, tab size
- **Editor:** External editor path, external diff tool, external merge tool
- **Accounts:** Linked hosting provider accounts (see #8)
- **Credentials:** SSH keys, PATs
- **Keyboard shortcuts:** Customizable keybindings
- **Advanced:** Custom git binary path, environment variables, proxy settings

**New files:**
- `lib/features/settings/settings_screen.dart`
- `lib/features/settings/settings_bloc.dart`
- `lib/core/settings_service.dart`

---

### 21. File Browser / Tree View

**Current:** No way to browse the repo's file tree at any commit.

**Required:**
- `git ls-tree -r --name-only <ref>` for file listing
- Tree view widget showing folder hierarchy
- Click file to view contents at that commit
- Right-click for: Blame, History, Open in editor
- Accessible from sidebar and commit detail panel

---

### 22. Auto-Refresh / File Watching

**Current:** The `watcher` package is a dependency but completely unused. Changes made outside
the app (command line, IDE, etc.) are never detected.

**Required:**
- Watch `.git/HEAD`, `.git/index`, and working tree for changes
- Debounce file system events (100-200ms)
- Auto-refresh status, staging panel, and current branch on external changes
- Configurable enable/disable in settings

---

### 23. Resizable Panes

**Current:** Sidebar width (220px), commit detail height, and all column widths are fixed.

**Required:**
- Draggable splitter between sidebar and main content
- Draggable splitter between commit graph and detail panel
- Draggable column dividers in commit graph table (Graph, Description, Author, Date, SHA)
- Persist pane sizes across sessions

**Dependency to add:** `multi_split_view` or custom `GestureDetector` splitters.

---

### 24. Window Management

**Current:** Title bar traffic lights and min/max/close buttons are decorative icons with no
functionality. Title bar is not draggable.

**Required:**
- Wire traffic lights / window controls to `windowManager.minimize()`, `.maximize()`, `.close()`
- Make title bar draggable with `windowManager.startDragging()`
- Double-click title bar to maximize/restore
- Persist window size and position across launches
- Handle tab overflow in title bar (horizontal scroll or dropdown)

---

### 25. Menu Bar

**Current:** No application menu bar.

**Required menus:**

| Menu | Items |
|------|-------|
| File | Open, Clone, Init, Close Tab, Settings, Quit |
| Edit | Undo, Redo, Cut, Copy, Paste, Select All, Find |
| View | Toggle Sidebar, Toggle Console, Zoom In/Out, Reset Zoom |
| Repository | Fetch, Pull, Push, Stash, Refresh |
| Branch | New Branch, Merge, Rebase, Checkout |
| Help | About, Check for Updates, Documentation |

**Implementation:** Use `PlatformMenuBar` widget for native macOS menu bar, custom menu bar widget
for Linux/Windows.

---

### 26. Commit Graph Improvements

**Current issues:**
- Only loads 100 commits with no pagination
- Lane compaction is absent (lanes grow monotonically)
- No commit context menu
- No relative dates
- No author avatars
- No column resizing

**Required:**
- Infinite scroll with `LoadMoreCommitsEvent` (load 100 more on scroll-to-bottom)
- Lane reclamation: when a lane's branch merges, free that lane for reuse
- Lane crossing minimization algorithm
- Merge commits shown as diamonds or larger dots
- Relative date display ("3 hours ago", "2 days ago")
- Gravatar integration for author avatars
- Column resize handles
- Multi-select for commit range operations

---

### 27. Ahead/Behind Indicators on Branches

**Current:** `BranchEntity` has `ahead` and `behind` fields populated by the git engine but the
sidebar UI never displays them.

**Fix:** Show `↑2 ↓1` badges next to branch names in the sidebar when ahead/behind values are
non-null and non-zero.

---

## 🟡 P2 — Medium Priority (Professional Polish)

### 28. Git LFS Support

- Detect LFS-tracked files (`.gitattributes` parsing)
- `git lfs install`, `git lfs pull`, `git lfs push`, `git lfs track`
- Show LFS status in file listings (pointer vs. actual content)
- LFS lock/unlock support

### 29. GPG / SSH Commit Signing

- Detect signing configuration from git config
- Sign commits and tags when configured
- Verify signature on commits and display status (✅ Verified / ❌ Unverified)
- SSH signing support (`gpg.format = ssh`)

### 30. Worktree Support

- `git worktree list`, `add`, `remove`, `prune`
- Sidebar section showing active worktrees
- Open worktree as separate tab
- Create worktree from branch context menu

### 31. Reflog Viewer

- `git reflog` parsing
- Dedicated panel showing reflog entries
- "Undo" operations by resetting to reflog entries
- Accessible from Repository menu

### 32. Terminal / Console Output Panel

- Toggleable bottom panel showing raw git command output
- Shows all commands executed by the app with timestamps
- Copyable output for debugging
- Manual command entry (advanced users)

### 33. Image Diff Support

- Detect image files in diffs (png, jpg, gif, svg, webp)
- Side-by-side image comparison
- Swipe/slider overlay comparison
- Difference highlighting

### 34. Search Across Files (Grep)

- `git grep <query>` with results panel
- File-level and line-level results
- Click to open file at matching line
- Regex support

### 35. Multi-Select Operations

- Shift+click and Cmd/Ctrl+click in file lists for multi-select
- Stage/unstage/discard multiple files at once
- Multi-commit selection for range diff

### 36. Undo/Redo Stack

- Track recent operations (stage, unstage, commit, checkout)
- Undo last operation (soft reset, re-stage, etc.)
- Redo support
- Visual undo history

### 37. Word-Level Inline Diff Highlighting

- Within changed lines, highlight the specific characters/words that differ
- Use red/green background on changed character ranges
- Algorithm: longest common subsequence on line pairs

### 38. Commit Message Helpers

- Character counter (50-char subject guideline, 72-char body wrap)
- Conventional commit prefix dropdown (feat:, fix:, chore:, docs:, etc.)
- Message templates (customizable in settings)
- Auto-wrap body at 72 characters

### 39. Light Theme and Theme Switching

- Complete light color palette mirroring the dark theme
- System theme auto-detection
- Runtime switching without restart
- Settings persistence

### 40. Drag-and-Drop

- Drag folder onto welcome screen to open as repo
- Drag branch onto another branch in sidebar to merge
- Drag commit to branch to cherry-pick
- Drag tab to reorder

---

## 🧹 Cleanup — Dead Dependencies

The following packages are declared in `pubspec.yaml` but completely unused. They should be
either removed or integrated:

| Package | Status | Action |
|---------|--------|--------|
| `git2dart: ^0.5.2` | Unused (entire engine is CLI-based) | **Remove** |
| `re_highlight: ^0.0.3` | Unused (no syntax highlighting) | **Integrate** (see #13) or remove |
| `google_fonts: ^8.1.0` | Unused (fonts hardcoded as strings) | **Integrate** — use for Inter/JetBrains Mono |
| `flutter_svg: ^2.3.0` | Unused (no SVG assets) | **Integrate** for icons or remove |
| `hydrated_bloc: ^0.0.0` | Unused (no persisted blocs) | Remove or integrate for settings persistence |
| `bloc_concurrency: ^0.3.0` | Unused (no event transformers) | **Integrate** — add `droppable()` to debounce rapid events |
| `watcher: ^1.2.1` | Unused (no file watching) | **Integrate** (see #22) |
| `rxdart: ^0.28.0` | Unused (no reactive streams) | Remove or integrate for debounced search |
| `uuid: ^4.5.3` | Unused (tab IDs use timestamps) | **Integrate** — replace timestamp tab IDs |
| `path: ^1.9.1` | Unused | **Integrate** for cross-platform path manipulation |

---

## 🧪 Test Coverage

**Current state:** 3 test files total — 1 unit test, 1 widget smoke test, 1 integration test.
Coverage is extremely minimal.

**Required:**
- Unit tests for `RealGitService` output parsing (status, branches, commits, diff, stash)
- Unit tests for `GraphLayoutBuilder` lane assignment algorithm
- BLoC tests for every bloc (repository, sidebar, staging, commit graph, diff viewer)
- Widget tests for all panels (sidebar, staging, diff, commit graph)
- Integration tests for full workflows (clone → branch → commit → merge → push)
- Golden image tests for the commit graph painter
- Edge case tests: empty repos, repos with no commits, repos with 10,000+ commits, binary
  files, non-ASCII filenames, merge conflicts, detached HEAD state

---

## 📋 Implementation Priority Order

1. **Fix critical bugs** (#1-6) — These cause crashes or data loss
2. **Merge conflict resolution** (#11) — Unusable as a Git client without this
3. **SSH authentication + credential management** (#7) — Most users need SSH
4. **Rebase, cherry-pick, reset, revert** (#9, #10) — Core Git operations
5. **Hosting provider integration** (#8) — GitHub/Azure DevOps/Bitbucket/GitLab
6. **Submodule UI** (#14) — Requested feature
7. **Context menus** (#15) — Expected interaction pattern
8. **Keyboard shortcuts** (#16) — Power user requirement
9. **Settings UI** (#20) — Needed for customization
10. **Split diff + syntax highlighting** (#12, #13) — Visual quality
11. **Everything else in P1** (#17-27)
12. **P2 polish items** (#28-40)
13. **Dead dependency cleanup**
14. **Test coverage expansion**
