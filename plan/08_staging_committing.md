# 08 — Staging & Committing

## Overview

The staging and committing workflow is the primary way users interact with their working copy. This covers the "Changes" view in Branched: displaying unstaged/staged files, staging/unstaging operations (file-level and hunk-level), the diff preview, and the commit message form.

---

## Working Copy View Layout

When "Changes" is selected in the sidebar:

```
┌────────────────────────────────────────────────────────────────────┐
│  Unstaged Changes (3)                         [ Stage All ▲ ]     │
├───────────────────────────────┬────────────────────────────────────┤
│ M  src/bloc/app_bloc.dart     │  @@ -12,6 +12,8 @@               │
│ A  src/new_feature.dart       │  context line                      │
│ ?  untracked_file.txt         │  context line                      │
│                               │ -old code line                     │
│                               │ +new code line                     │
│                               │ +another new line                  │
│                               │  context line                      │
├───────────────────────────────┤                                    │
│  Staged Changes (1)           │                                    │
│              [ Unstage All ▼ ]│                                    │
├───────────────────────────────┤                                    │
│ M  pubspec.yaml               │                                    │
│                               │                                    │
├───────────────────────────────┴────────────────────────────────────┤
│  Commit Message:                                                   │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Summary line (< 72 chars)                                    │  │
│  ├──────────────────────────────────────────────────────────────┤  │
│  │ Extended description...                                      │  │
│  │                                                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  [ ] Amend last commit        Author: User <user@email.com>       │
│                                                  [ Commit ]       │
└────────────────────────────────────────────────────────────────────┘
```

---

## File Lists

### Unstaged Changes Section

Shows files that have been modified, added, or deleted in the working tree but not yet staged.

| File Status | Icon | Color | Description |
|-------------|------|-------|-------------|
| Modified | `M` | Yellow | File content changed |
| Added (untracked) | `?` | Green | New file not tracked by git |
| Deleted | `D` | Red | File deleted from working tree |
| Renamed | `R` | Blue | File moved/renamed |
| Type Changed | `T` | Cyan | File type changed (e.g., file → symlink) |

### Staged Changes Section

Shows files added to the index (staged for next commit).

Same status icons, but represents the diff between index and HEAD.

### File List Interactions

| Action | Trigger | Scope |
|--------|---------|-------|
| Stage file | Click `+` button on file row | Single file |
| Stage file | Double-click file in unstaged list | Single file |
| Unstage file | Click `−` button on file row | Single file |
| Unstage file | Double-click file in staged list | Single file |
| Stage all | "Stage All" button | All unstaged files |
| Unstage all | "Unstage All" button | All staged files |
| Discard file | Right-click → Discard Changes | Single file |
| Discard all | Button or menu option | All unstaged changes |
| Select file | Single click | Shows diff in right panel |
| Open in editor | Right-click → Open in Editor | Opens in system editor |
| Copy path | Right-click → Copy Path | Copies to clipboard |

### File List Sorting

- Sort by: status, then alphabetically by path
- Group by directory (optional, toggle in settings)

---

## Hunk-Level Staging

Branched supports staging individual hunks (sections of changes) within a file, not just whole files.

### Hunk View in Diff Panel

```
@@ -12,6 +12,8 @@ class AppBloc {                    [Stage Hunk ▲]
  context line
  context line
- old code line
+ new code line
+ another new line
  context line

@@ -45,3 +47,5 @@ void initState() {                [Stage Hunk ▲]
  context line
+ added initialization
+ added setup
  context line
```

### Hunk Actions

| Action | Trigger |
|--------|---------|
| Stage hunk | Click "Stage Hunk" button on hunk header |
| Unstage hunk | Click "Unstage Hunk" button (when viewing staged file) |
| Discard hunk | Right-click hunk → "Discard Hunk" |
| Stage selected lines | Select specific lines → right-click → "Stage Lines" |

### Implementation

- `GitService.stageHunk(repo, path, hunk)`:
  - Apply only the selected hunk to the index
  - Uses git2dart's index manipulation (apply patch to index)
  - For line-level staging: construct a partial patch with only selected lines

---

## Commit Message Form

### Layout

```
┌──────────────────────────────────────────────────────────────────┐
│ Summary:   feat: add user authentication                         │  ← Single line, 72 char soft limit
├──────────────────────────────────────────────────────────────────┤
│ Description:                                                     │  ← Multi-line, expandable
│ - Added login page with email/password                           │
│ - Added password validation                                      │
│ - Integrated auth API                                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
│ [ ] Amend last commit                                            │
│ Author: John Doe <john@example.com>   [ Commit (Cmd+Enter) ]    │
```

### Commit Message Rules

| Rule | Behavior |
|------|----------|
| Summary ≤ 72 chars | Show character counter, warn when exceeding |
| Summary required | Commit button disabled when empty |
| Empty line between summary and body | Automatically handled by split input fields |
| Staged files required | Commit button disabled when no staged files |
| Author from git config | Auto-filled from repo's user.name + user.email |

### CommitFormCubit State

```
CommitFormState {
  String summary,
  String description,
  bool isAmend,
  bool isSubmitting,
  bool canCommit,              // summary not empty AND staged files > 0
  AuthorEntity author,
  String? error,
  CommitEntity? lastCommit,    // for amend: pre-fills with last commit message
}
```

### Amend Mode

When "Amend last commit" is checked:
1. Load the last commit's message into the form fields
2. Stage area shows files from the last commit + any new staged files
3. Commit replaces the last commit (rewrite SHA)

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + Enter` | Commit (when commit form is focused) |
| `Cmd/Ctrl + Shift + A` | Stage all |
| `Cmd/Ctrl + Shift + U` | Unstage all |

---

## Commit Flow

```
1. User writes commit message
2. User clicks [ Commit ] or presses Cmd+Enter
3. CommitFormCubit.submit()
4. GitService.createCommit(repo, message, author, amend)
5. On success:
   a. Clear commit form
   b. StagingBloc.RefreshWorkingCopy (staged list empties)
   c. CommitGraphBloc.RefreshGraph (new commit appears)
   d. SidebarBloc.RefreshSidebar (branch tip updates)
   e. Show success notification
6. On failure:
   a. Show error in commit form
   b. Don't clear the message
```

---

## Diff Preview (Right Panel)

When a file is selected in the unstaged or staged list, show its diff in the right panel.

- **Unstaged file selected**: Show diff between working tree and index (unstaged changes)
- **Staged file selected**: Show diff between index and HEAD (staged changes)
- See `09_diff_viewer.md` for full diff viewer specification

---

## Discard Changes

### Discard Single File

```
┌──────────────────────────────────────┐
│  Discard Changes?               [✕]  │
├──────────────────────────────────────┤
│                                      │
│  Discard changes to:                 │
│  src/bloc/app_bloc.dart              │
│                                      │
│  ⚠ This action cannot be undone!    │
│                                      │
│              [ Cancel ]  [ Discard ] │
└──────────────────────────────────────┘
```

### Discard All Changes

Same dialog but for all files. Extra warning emphasis.

### Implementation

- Modified files: `GitService.discardFile(repo, path)` — restores from HEAD
- New/untracked files: Delete from filesystem (with confirmation)
- Deleted files: Restore from HEAD

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Large number of files (1000+) | Virtualized list, load on demand |
| Binary files | Show "Binary file changed" instead of diff |
| Very large files (>1MB diff) | Show warning, offer to open externally |
| File permissions changed | Show as type change |
| Submodule changes | Show submodule commit SHA change |
| Empty commit (no staged files) | Disable commit button with tooltip |
| Commit during merge | Show merge commit message template |
| Commit during rebase | Handle "continue rebase" flow instead |
| Renamed file with changes | Show both rename and content diff |
