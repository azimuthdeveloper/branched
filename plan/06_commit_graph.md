# 06 — Commit Graph (DAG Visualization)

## Overview

The commit graph is the centerpiece of Branched's UI — a scrollable, colored, lane-based visualization of the Git DAG (Directed Acyclic Graph). This is the most technically challenging component of the entire application.

---

## Visual Specification

```
  Lane 0  Lane 1  Lane 2
    │       │       │
    ●───────┤       │     "Merge feature into main"       Alice    2h ago   a1b2c3d
    │       │       │
    │       ●       │     "Add login screen"               Bob      3h ago   d4e5f6a
    │       │       │
    │       ●───────┤     "Merge hotfix into feature"      Bob      5h ago   b7c8d9e
    │       │       │
    ●       │       │     "Update CI pipeline"             Alice    1d ago   e0f1a2b
    │       │       │
    │       │       ●     "Fix crash on startup"           Carol    1d ago   c3d4e5f
    │       │      ╱
    │       ●─────╯       "Start hotfix branch"            Carol    2d ago   f6a7b8c
    │       │
    ●───────╯             "Initial commit"                  Alice    1w ago   a9b0c1d
```

### Rendering Rules

| Element | Spec |
|---------|------|
| **Commit dot** | 8px diameter circle, filled with lane color |
| **Lane line** | 2px stroke, lane color, vertical |
| **Merge line** | 2px stroke, curved bezier, from child to parent |
| **Lane spacing** | 14px horizontal between lanes |
| **Row height** | 24px per commit |
| **HEAD dot** | Double circle (or highlighted ring) |
| **Active branch dot** | Slightly larger (10px) |

### Lane Colors (rotating palette)

```
Index 0: #4EC9B0  (teal)
Index 1: #569CD6  (blue)
Index 2: #C586C0  (purple)
Index 3: #CE9178  (orange)
Index 4: #DCDCAA  (yellow)
Index 5: #D16969  (red)
Index 6: #4FC1FF  (cyan)
Index 7: #C8C864  (lime)
Index 8: #D7BA7D  (gold)
Index 9: #B5CEA8  (green)
```

Colors repeat after index 9. Assign based on branch origin.

---

## DAG Layout Algorithm

### Phase 1: Topological Sort

1. Start from HEAD (or all branch tips if showing all branches)
2. Walk parents in reverse chronological order
3. Produce a flat list of commits sorted by timestamp (newest first)
4. Respect topological ordering: a parent always appears after all its children

### Phase 2: Lane Assignment

The lane assignment algorithm determines which vertical column each commit occupies.

```
Algorithm: GreedyLaneAssignment

Input:  sorted commits (newest first)
Output: each commit gets a laneIndex

State:  activeLanes: Map<String, int>  // sha → lane index
        laneCount: int = 0

For each commit in sorted order:
  1. If commit.sha is in activeLanes:
       - Use that lane
       - Remove from activeLanes
     Else:
       - Assign next available lane (laneCount++)

  2. For each parent of commit (in order):
     - If parent.sha is already in activeLanes:
         - Record a merge connection (from commit's lane to parent's lane)
     - Else if it's the first parent:
         - Parent inherits commit's lane
         - activeLanes[parent.sha] = commit.laneIndex
     - Else:
         - Assign a new lane to parent
         - activeLanes[parent.sha] = laneCount++
         - Record a branch connection

  3. Compact lanes: if any lane is no longer used, mark it free for reuse
```

### Phase 3: Connection Generation

For each commit, generate `GraphConnection` objects:

| Connection Type | When |
|----------------|------|
| `straight` | Commit continues on same lane as its first parent |
| `mergeLeft` | Line curves left to merge into a lower-index lane |
| `mergeRight` | Line curves right to merge into a higher-index lane |
| `branchLeft` | Line curves left to create a new branch lane |
| `branchRight` | Line curves right to create a new branch lane |

---

## Rendering with CustomPainter

The graph column uses a `CustomPainter` for high-performance rendering.

### GraphPainter

- Receives: `List<GraphCommit>` (visible commits in viewport), `ScrollOffset`
- Paints only visible rows (virtualized — not the full history)
- For each visible commit row:
  1. Draw active lane lines (vertical lines through the row)
  2. Draw connections (bezier curves for merges/branches)
  3. Draw commit dot

### Bezier Curves for Merge/Branch Lines

```
Merge line (from lane 2 to lane 0):

  Start:  (lane2_x, row_top)
  Control: (lane2_x, row_center), (lane0_x, row_center)
  End:    (lane0_x, row_bottom)

Use cubic bezier for smooth curves.
```

### Anti-Aliasing

- Enable anti-aliasing on all paint operations
- Use `Paint..isAntiAlias = true`

---

## Virtualized Scrolling

The commit list can have thousands or millions of entries. Must use virtualization.

### Strategy

- Use a `ListView.builder` (or custom `Scrollable` + `SliverList`)
- Load commits in pages of 100
- When user scrolls near bottom (within 20 items), load next page
- CommitGraphBloc dispatches `LoadMoreCommits`
- Total visible at once: ~40 rows (typical window height)

### Smooth Scrolling

- Pre-load 2 pages ahead of current scroll position
- Keep 5 pages in memory, dispose older pages
- Fixed row height (24px) enables predictable scroll calculations

---

## Branch & Tag Labels

Inline badges displayed next to the commit message:

```
●── Merge feature into main  [main] [origin/main] [v1.2.0]
```

### Label Rendering

| Type | Style |
|------|-------|
| Local branch | Rounded badge, lane color background, white text |
| Remote branch | Rounded badge, muted/darker background, prefix with remote name |
| Tag | Rounded badge, distinct style (e.g., outlined or different shape) |
| HEAD | Special indicator (★ or bold ring on dot) |

### Label Data

From `CommitEntity.refs`:
```
RefEntity {
  String name,
  RefType type,     // localBranch, remoteBranch, tag
  String? remote,   // "origin" for remote branches
}
```

---

## Commit List Columns

Right side of the graph column, implemented as a table:

| Column | Width | Alignment | Content |
|--------|-------|-----------|---------|
| Graph | Variable (auto-fits lanes) | — | Custom painted graph |
| Description | Flex (remaining space) | Left | First line of commit message + badges |
| Author | 120px | Left | Author name (truncated) |
| Date | 120px | Right | Relative time ("2h ago") or absolute |
| SHA | 70px | Left | First 7 characters, monospace |

### Column Resizing

- Columns are resizable by dragging header dividers
- Persist column widths in `PanelLayoutCubit`

### Column Header

```
| Graph | Description ↓ | Author | Date | SHA |
```

- Click header to sort (description, author, date)
- Arrow indicates sort direction
- Default sort: chronological (topological order)

---

## Interactions

### Commit Selection

- Single click: select commit → load detail in bottom panel
- Double-click: open commit in full detail view
- Keyboard: arrow up/down to navigate, Enter to select

### Commit Context Menu (right-click)

| Menu Item | Action |
|-----------|--------|
| Checkout | Detached HEAD at this commit |
| Create Branch Here | Opens branch creation dialog |
| Create Tag Here | Opens tag creation dialog |
| Cherry-Pick | Cherry-picks this commit onto current branch |
| Revert | Creates a revert commit |
| Reset Current Branch to Here | Sub-menu: Soft / Mixed / Hard |
| Copy SHA | Copies full SHA to clipboard |
| Copy Commit Message | Copies commit message |
| Browse Files at This Commit | Opens file tree at this commit |

### Branch Label Interactions

- Click branch label: checkout that branch
- Right-click: branch context menu (merge, rebase, delete, etc.)
- Drag branch label onto another: merge dialog

---

## Merge Commit Collapsing

Branched supports expanding/collapsing merge commits to simplify the graph.

### Behavior

- Merge commits (2+ parents) show a collapse toggle
- When collapsed: all commits between the merge and its merge base are hidden
- The graph shows a simplified "merged" indicator
- Toggle via click on a collapse icon or keyboard shortcut

### Implementation

- `CommitGraphBloc` maintains `Set<String> collapsedMerges`
- When building the visible list, filter out hidden commits
- Recalculate lane layout for the visible subset

---

## Search Integration

### Quick Search (Filter Bar)

```
┌─ 🔍 Search commits... ────────────────────────────┐
```

- Filter as you type (debounced 300ms)
- Search in: commit message, author name, SHA
- Highlighted matches in results
- Clear button to remove filter

### Jump to Commit

- `Cmd/Ctrl + G`: Jump to SHA dialog
- Enter a SHA (partial or full)
- Scrolls to and selects that commit

---

## Performance Targets

| Metric | Target |
|--------|--------|
| Initial load (100 commits) | < 200ms |
| Scroll to next page (100 commits) | < 100ms |
| Graph render (visible viewport) | < 16ms (60fps) |
| Full graph rebuild | < 500ms for 10K commits |
| Memory (1000 commits loaded) | < 50MB |
| Memory (10000 commits loaded) | < 200MB |

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Repository with 100K+ commits | Virtualization + pagination |
| Octopus merge (3+ parents) | Support N-parent connections |
| Detached HEAD | Show special indicator, no branch label |
| Empty repository | Show "No commits yet" message |
| Orphan branches | Separate graph section or indicator |
| Very wide graph (20+ lanes) | Horizontal scrolling, or collapse inactive lanes |
