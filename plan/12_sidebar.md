# 12 — Sidebar

## Overview

The sidebar is the left panel of the application, providing hierarchical navigation through the repository's branches, remotes, tags, stashes, and submodules. It mirrors Branched's sidebar exactly.

---

## Sidebar Layout

```
┌─────────────────────────┐
│ 🔍 Filter...            │  ← Filter input
├─────────────────────────┤
│                         │
│ ● Changes         (3)  │  ← Special: working copy view
│                         │
│ ▾ Branches              │
│   ● main            ◄  │  ← Current branch (bold + indicator)
│     feature/auth        │
│     feature/graph       │
│     hotfix/crash-fix    │
│                         │
│ ▾ Remotes               │
│   ▾ origin              │
│       main              │
│       develop           │
│       feature/auth      │
│   ▸ upstream            │
│                         │
│ ▸ Tags            (5)  │
│                         │
│ ▸ Stashes          (2) │
│                         │
│ ▸ Submodules       (1) │
│                         │
└─────────────────────────┘
```

---

## Section Details

### Changes (Working Copy)

| Element | Detail |
|---------|--------|
| Always visible | First item, always at top |
| Badge | Count of uncommitted files (staged + unstaged) |
| Selection | Switches main content to Working Copy view |
| Icon | Filled circle (●) when changes exist, empty (○) when clean |
| Highlight | Accent color when repo has uncommitted changes |

### Branches (Local)

| Element | Detail |
|---------|--------|
| Section header | "Branches" — collapsible |
| Items | All local branches |
| Current branch | Bold text + filled indicator (● or ◄ arrow) |
| Sorting | Alphabetical, with current branch first |
| Grouping | Branches with `/` in names group hierarchically (e.g., `feature/auth` under `feature/`) |
| Context menu | Checkout, Merge, Rebase, Rename, Delete, Copy Name |
| Double-click | Checkout branch |
| Drag & Drop | Drag onto another branch to merge |

### Branch Grouping

When branches share a prefix with `/`:

```
▾ Branches
  ● main
  ▾ feature/
      auth
      graph
      payment
  ▸ hotfix/
      crash-fix
  ▸ release/
      v2.0
```

### Remotes

| Element | Detail |
|---------|--------|
| Section header | "Remotes" — collapsible |
| Sub-sections | One collapsible group per remote (origin, upstream, etc.) |
| Items | Remote-tracking branches under each remote |
| Context menu (remote) | Fetch, Edit URL, Remove |
| Context menu (branch) | Checkout as local, Delete remote branch, Copy Name |
| Expand behavior | Collapsed by default; expand to see branches |

### Tags

| Element | Detail |
|---------|--------|
| Section header | "Tags" — collapsible |
| Badge | Count of tags |
| Items | All tags, sorted by date (newest first) or alphabetically |
| Display | Tag name + target SHA (truncated) |
| Annotated tags | Show 📝 icon if annotated |
| Context menu | Checkout, Delete, Push Tag, Copy Name |
| Expand behavior | Collapsed by default |

### Stashes

| Element | Detail |
|---------|--------|
| Section header | "Stashes" — collapsible |
| Badge | Count of stashes |
| Items | `stash@{0}: message`, `stash@{1}: message`, etc. |
| Context menu | Apply, Pop, Drop, View Changes |
| Display | Index + message, truncated to sidebar width |

### Submodules

| Element | Detail |
|---------|--------|
| Section header | "Submodules" — collapsible |
| Badge | Count of submodules |
| Items | Submodule path + current commit |
| Context menu | Open in New Tab, Update, View in File Manager |
| Status indicator | Show if submodule has uncommitted changes or needs update |

---

## Filter / Search Input

```
┌────────────────────────┐
│ 🔍 Filter branches...  │
└────────────────────────┘
```

| Behavior | Detail |
|----------|--------|
| Scope | Filters ALL sections simultaneously |
| Matching | Case-insensitive substring match |
| Highlighting | Matching characters highlighted in results |
| Clear | X button or Escape key |
| Sections | Empty sections are hidden when filter is active |
| Debounce | 150ms debounce on input |
| Shortcut | `Cmd/Ctrl + Shift + B` focuses the filter input |

---

## Sidebar Interactions

### Selection

- Single click: select item
- Selection shows full-width highlight bar with accent color
- Only one item selected at a time
- Selection drives main content view:
  - Branch selected → CommitGraph filtered to that branch
  - "Changes" selected → Working Copy view
  - Tag selected → Jump to tagged commit in graph
  - Stash selected → Show stash contents in detail panel

### Context Menus

#### Branch Context Menu

```
┌─────────────────────────┐
│ Checkout                │
│ ───────────────────────│
│ Merge into 'main'      │
│ Rebase 'main' onto this│
│ ───────────────────────│
│ Rename                  │
│ Delete                  │
│ ───────────────────────│
│ Copy Branch Name        │
└─────────────────────────┘
```

#### Remote Branch Context Menu

```
┌──────────────────────────────┐
│ Checkout as Local Branch     │
│ ─────────────────────────── │
│ Delete Remote Branch         │
│ ─────────────────────────── │
│ Copy Branch Name             │
└──────────────────────────────┘
```

#### Tag Context Menu

```
┌─────────────────────────┐
│ Checkout                │
│ ───────────────────────│
│ Delete Tag              │
│ Push Tag to Remote      │
│ ───────────────────────│
│ Copy Tag Name           │
│ Copy SHA                │
└─────────────────────────┘
```

#### Stash Context Menu

```
┌─────────────────────────┐
│ Apply Stash             │
│ Pop Stash               │
│ Drop Stash              │
│ ───────────────────────│
│ View Stash Changes      │
└─────────────────────────┘
```

### Drag & Drop

| Drag Source | Drop Target | Action |
|-------------|-------------|--------|
| Local branch | Another local branch | Open merge dialog (drag into target) |
| Local branch | Remote branch | Push dialog |
| Remote branch | Local branch | Merge dialog |

---

## Sidebar Resize

| Property | Value |
|----------|-------|
| Default width | 220px |
| Minimum width | 150px |
| Maximum width | 400px |
| Resize handle | 4px wide, on right edge |
| Cursor | `col-resize` on hover |
| Double-click handle | Reset to default (220px) |
| Collapse | Toggle button or keyboard shortcut (`Cmd/Ctrl + B`) |
| Collapsed state | Hide sidebar completely (0px), show toggle button on left edge |

---

## Tree View Implementation

Use `flutter_fancy_tree_view` or custom `TreeView` widget.

### Tree Node Model

```
SidebarNode {
  String id,
  String label,
  SidebarNodeType type,        // section, branch, remoteBranch, tag, stash, submodule, group
  String? icon,
  bool isExpanded,
  bool isSelected,
  bool isCurrent,              // true for current branch
  int? badgeCount,
  List<SidebarNode> children,
}
```

### Rendering

- Indent: 16px per level
- Row height: 24px
- Disclosure triangle: 12×12px, clickable
- Icon: 16×16px
- Text: 13px, ellipsis overflow
- Full-width selection highlight
- Hover: subtle background change

---

## Data Flow

```
SidebarBloc
  ├── LoadSidebarData (on repo open)
  │   └── GitService.getBranches() + getRemoteBranches() + getTags() + getStashes()
  │       └── Build tree structure from flat lists
  │
  ├── RefreshSidebar (on file watcher change)
  │   └── Re-fetch all data, diff with current state, update only changed items
  │
  ├── SelectItem (on click)
  │   └── Update selectedItem in state
  │   └── Notify CommitGraphBloc via BlocListener
  │
  ├── ToggleSection (on header click)
  │   └── Update expandedSections set
  │
  └── FilterItems (on search input)
      └── Filter all nodes by query, rebuild visible tree
```

---

## Performance

| Metric | Target |
|--------|--------|
| Initial load | < 100ms for 100 branches |
| Filter response | < 50ms |
| Refresh after git op | < 100ms |
| Memory for 1000 branches | < 5MB |

### Optimization

- Use diff-based updates (don't rebuild entire tree on refresh)
- Collapsed sections: don't query children until expanded
- Remotes: lazy-load branches per remote on expand
