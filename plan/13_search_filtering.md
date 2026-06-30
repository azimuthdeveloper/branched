# 13 — Search & Filtering

## Overview

Search and filtering is used throughout Furcate: filtering commits by message/author/SHA, searching file contents, filtering branches in the sidebar, and quick navigation via command palette.

---

## Search Types

### 1. Commit Search (Commit Graph)

```
┌─────────────────────────────────────────────────────────────────────┐
│ 🔍 Search commits...  │ [Message ▾] │ [All Branches ▾] │ [✕ Clear]│
└─────────────────────────────────────────────────────────────────────┘
```

| Filter | Options | Default |
|--------|---------|---------|
| Search in | Message, Author, SHA, All | All |
| Branch scope | Current branch, All branches, Specific branch | All |
| Date range | From / To date pickers | No limit |
| Author filter | Dropdown of all authors | All |

**Behavior:**
- Debounced (300ms) search-as-you-type
- Results highlight matching text in the commit list
- Non-matching commits are hidden or dimmed
- Result count shown: "42 commits match"
- Clear button resets all filters

**SearchBloc interaction:**
```
SearchCommits(query, scope, dateRange, author)
  → GitService.searchCommits(repo, query, options)
  → CommitGraphBloc receives filtered list
```

### 2. Branch Filter (Sidebar)

See `12_sidebar.md` — inline filter input at top of sidebar.

### 3. File Search (in Working Copy / Commit Detail)

Search for files by name in the changed files list:

```
┌──────────────────────────┐
│ 🔍 Filter files...       │
└──────────────────────────┘
```

- Filters the file list in staging area or commit detail
- Case-insensitive substring match
- Instant (no debounce needed for small lists)

### 4. Find in Diff (Diff Viewer)

Standard find-in-text for the diff content:

```
┌──────────────────────────────────────────────┐
│ Find: [ search term    ] │ ▲ ▼ │ 3 of 12  │ ✕│
│ [ ] Match case  [ ] Regex  [ ] Whole word    │
└──────────────────────────────────────────────┘
```

- `Cmd/Ctrl + F` to open
- Navigate results with `Enter` / `Shift+Enter` or arrow buttons
- Highlight all matches in the diff content
- Current match highlighted more prominently
- Options: case sensitive, regex, whole word

---

## Command Palette

Quick navigation / action launcher (like VS Code's `Cmd+Shift+P`):

### Activation

- `Cmd/Ctrl + P`: Quick open (repositories, branches, files)
- `Cmd/Ctrl + Shift + P`: Command palette (all actions)

### Quick Open (`Cmd+P`)

```
┌──────────────────────────────────────────────────────┐
│ > _                                                   │
├──────────────────────────────────────────────────────┤
│ 📁 Recent Repositories                               │
│     my-project (~/code/my-project)                   │
│     flutter-app (~/code/flutter-app)                 │
│                                                       │
│ 🔀 Branches                                          │
│     main                                              │
│     feature/auth                                      │
│     feature/graph                                     │
│                                                       │
│ 🏷 Tags                                              │
│     v1.2.0                                            │
│     v1.1.0                                            │
└──────────────────────────────────────────────────────┘
```

**Behavior:**
- Fuzzy matching on input
- Grouped results: Repos → Branches → Tags → Commits
- Enter to select: checkout branch, open repo, jump to commit
- Arrow keys to navigate
- Escape to close
- Type prefix to filter by type:
  - `#` → Search commits by SHA
  - `@` → Search by author
  - `>` → Commands (same as Cmd+Shift+P)

### Command Palette (`Cmd+Shift+P`)

```
┌──────────────────────────────────────────────────────┐
│ > _                                                   │
├──────────────────────────────────────────────────────┤
│ 🔀 Checkout Branch                                   │
│ 📥 Clone Repository                                  │
│ 📂 Open Repository                                   │
│ 🔃 Fetch                                             │
│ 📤 Push                                              │
│ 📥 Pull                                              │
│ 📦 Stash Changes                                     │
│ 🏷 Create Tag                                        │
│ ⚙ Open Settings                                     │
│ 🌙 Toggle Dark Mode                                  │
└──────────────────────────────────────────────────────┘
```

Lists all available actions with fuzzy search filtering.

---

## Search Implementation

### Commit Search Implementation

```
1. Query enters SearchBloc
2. Apply debounce (restartable transformer, 300ms)
3. Search strategy:
   a. SHA search (if query looks like hex): git2dart object lookup
   b. Message search: iterate commits, filter by message.contains(query)
   c. Author search: filter by author.name or author.email
   d. Full text: search all fields
4. For large repos: search in isolate
5. Return matching commit SHAs
6. CommitGraphBloc highlights/filters to matching commits
```

### Fuzzy Matching for Command Palette

- Use a scoring algorithm (similar to fzf/Sublime Text):
  - Consecutive character matches score higher
  - Start-of-word matches score higher
  - Exact prefix matches score highest
- Sort by score descending
- Highlight matched characters in results

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + F` | Find in diff |
| `Cmd/Ctrl + P` | Quick open |
| `Cmd/Ctrl + Shift + P` | Command palette |
| `Cmd/Ctrl + G` | Go to commit SHA |
| `Cmd/Ctrl + Shift + B` | Focus sidebar filter |
| `Escape` | Close search / palette |
| `Enter` | Select result / go to next match |
| `Shift + Enter` | Go to previous match |
