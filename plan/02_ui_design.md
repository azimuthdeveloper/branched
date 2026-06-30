# 02 — UI Design & Theming

## Branched UI Anatomy

Branched's interface is a dense, information-rich IDE-like layout optimized for Git power users. Every pixel is deliberate. This document specifies the exact layout we must replicate.

---

## Master Layout Wireframe

```
┌──────────────────────────────────────────────────────────────────────┐
│ [●][●][●]   [ Repo A ][ Repo B ][ + ]           ─ □ ✕  │ Title Bar
├──────────────────────────────────────────────────────────────────────┤
│ ◀ ▶ │ ↓Fetch  ↓Pull  ↑Push │ Stash Pop │ Branch Merge Rebase │ ⚙  │ Toolbar
├────────────┬─────────────────────────────────────────────────────────┤
│ ▾ Branches │  ● ─── Commit message          Author     Date   SHA  │
│   main   ◄ │  │ ╲                                                   │
│   feature  │  ●  ● ─ Another commit         Author     Date   SHA  │
│   hotfix   │  │  │                                                   │
│            │  ●  │ ─ Merge branch            Author     Date   SHA  │
│ ▾ Remotes  │  │ ╱                                                   │
│  ▾ origin  │  ● ─── Fix bug #42             Author     Date   SHA  │
│    main    │  │                                                      │
│    develop │  ● ─── Initial commit           Author     Date   SHA  │
│            ├─────────────────────────────────────────────────────────┤
│ ▸ Tags     │  M  src/main.dart       │  - old line                  │
│ ▸ Stashes  │  A  src/new_file.dart    │  + new line                  │
│ ▸ Submod.  │  D  src/removed.dart     │  + another new line          │
│            │  R  src/renamed.dart      │    context line              │
├────────────┴──────────────────────────┴──────────────────────────────┤
│  main ↑0 ↓2   │   Ln 42, Col 8   │   UTF-8   │   LF              │ Status Bar
└──────────────────────────────────────────────────────────────────────┘
```

---

## Layout Zones (Top to Bottom)

### Zone 1: Title Bar (32–38px height)

| Element | Position | Behavior |
|---------|----------|----------|
| Traffic lights (macOS) / Window buttons | Left (macOS) or Right (Win/Linux) | Platform-adaptive |
| Repository tabs | Center, scrollable | Closable, reorderable, max-width ~200px per tab |
| Tab "+" button | After last tab | Opens repo picker |
| Window drag area | Empty space in title bar | Enables window dragging |

- Tab shows: repo name + dirty indicator (dot)
- Active tab: lighter background, bottom border accent
- Inactive tab: darker, muted text
- On macOS: leave 70px on the left for traffic light buttons

### Zone 2: Toolbar (36–40px height)

```
[ ← ][ → ] │ [ ↓ Fetch ][ ↓ Pull ][ ↑ Push ] │ [ Stash ][ Pop ] │ [ Branch ][ Merge ][ Rebase ] │ [ ⚙ ]
```

| Button Group | Actions | Notes |
|-------------|---------|-------|
| Navigation | Back, Forward | History navigation within the repo view |
| Sync | Fetch, Pull, Push | Show progress indicator during operation |
| Stash | Stash, Pop | Quick stash/pop of working changes |
| Branch Ops | Branch, Merge, Rebase | Open dialogs for each operation |
| Settings | Gear icon | Opens settings panel |

- Buttons: icon + text label, muted color, hover highlight
- Disabled state: 50% opacity when action is not available
- Active state: subtle press animation
- Dividers: vertical thin lines between groups

### Zone 3: Main Content (fills remaining space)

Split into **Sidebar** (left) and **Content Area** (right) with a draggable divider.

---

## Sidebar Design (220px default width, resizable 150–400px)

### Section Structure (top to bottom)

```
┌─────────────────────┐
│ 🔍 Filter branches  │  ← Search/filter input
├─────────────────────┤
│ ▾ Branches           │  ← Section header (collapsible)
│   ● main          ◄ │  ← Current branch (bold, dot indicator)
│     feature/auth     │
│     feature/graph    │
│     hotfix/crash     │
├─────────────────────┤
│ ▾ Remotes            │
│   ▾ origin           │
│       main           │
│       develop        │
│   ▸ upstream         │
├─────────────────────┤
│ ▸ Tags         (12)  │  ← Count badge
├─────────────────────┤
│ ▸ Stashes       (3)  │
├─────────────────────┤
│ ▸ Submodules    (1)  │
└─────────────────────┘
```

| Element | Spec |
|---------|------|
| Section headers | 11px, uppercase, semi-bold, muted color, left-aligned |
| Tree items | 13px, normal weight, full-width selectable |
| Indent | 16px per nesting level |
| Expand/collapse | Disclosure triangle (▾/▸), clickable |
| Current branch | Bold text + filled circle indicator |
| Selection | Full-width highlight bar, accent color background |
| Context menu | Right-click on any item opens context menu |
| Hover | Subtle background highlight |
| Count badges | Right-aligned, muted small text |

### Special Items

- **"Changes"** item at top (above Branches) — shows working copy view when selected
- Shows unstaged/staged count badges

---

## Commit Graph Area (Top Panel)

### Column Layout

```
│ Graph │ Description                    │ Author       │ Date         │ SHA     │
│ (var) │ (flex)                         │ (120px)      │ (120px)      │ (70px)  │
```

| Column | Width | Content |
|--------|-------|---------|
| Graph | Variable (50–200px) | Colored lane lines + commit dots |
| Description | Flex (fills remaining) | Commit message (first line), branch/tag labels as badges |
| Author | 120px | Author name, truncated |
| Date | 120px | Relative or absolute timestamp |
| SHA | 70px | First 7 characters of hash |

### Graph Rendering Specs

- **Commit dot**: 8px diameter circle, filled with lane color
- **Lane lines**: 2px width, rounded corners at junctions
- **Lane spacing**: 14px between parallel lanes
- **Colors**: Rotating palette of 10 visually distinct colors (see Color Palette below)
- **Merge connections**: Curved bezier lines connecting child to parents
- **HEAD indicator**: Different dot style (double circle or highlighted)
- **Branch labels**: Inline colored badges next to commit message (e.g., `[main]` `[origin/main]`)
- **Tag labels**: Distinct badge style (different shape/color from branches)

### Row Specs

- Row height: 24px
- Selected row: accent background
- Hover row: subtle highlight
- Alternating row colors: optional, very subtle

---

## Commit Detail Area (Bottom Panel, appears on commit select)

Split left/right with draggable divider.

### Left: Changed Files List

```
┌──────────────────────────┐
│ 4 changed files          │  ← Header with count
├──────────────────────────┤
│ M  src/main.dart         │  ← Status icon + file path
│ A  src/new_widget.dart   │
│ D  src/old_widget.dart   │
│ R  src/utils.dart → …    │
└──────────────────────────┘
```

| Status | Color | Icon |
|--------|-------|------|
| Modified (M) | Yellow/Orange | Filled dot or "M" |
| Added (A) | Green | "+" or "A" |
| Deleted (D) | Red | "−" or "D" |
| Renamed (R) | Blue | "→" or "R" |
| Copied (C) | Cyan | "C" |
| Conflicted (!) | Red, bold | "!" with warning |

### Right: Diff Viewer

See `09_diff_viewer.md` for full specification.

---

## Working Copy View (when "Changes" is selected)

```
┌────────────────────────────────────────────────────────────────────┐
│  Unstaged Changes (3 files)              [ Stage All ▲ ]          │
├──────────────────────────────┬─────────────────────────────────────┤
│ M  src/bloc/app_bloc.dart    │  @@ -12,6 +12,8 @@                 │
│ A  src/new_feature.dart      │  - old code line                   │
│ ?  untracked_file.txt        │  + new code line                   │
├──────────────────────────────┤  + another new line                 │
│  Staged Changes (1 file)     │    context line                    │
│            [ Unstage All ▼ ] │                                     │
├──────────────────────────────┤                                     │
│ M  pubspec.yaml              │                                     │
├──────────────────────────────┴─────────────────────────────────────┤
│  Commit Message:                                                   │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ feat: add new feature                                        │  │
│  │                                                              │  │
│  │ Detailed description here...                                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│  [ ] Amend last commit                        [ Commit ]          │
└────────────────────────────────────────────────────────────────────┘
```

---

## Color Palette

### Dark Theme (Primary — matches Branched's default look)

| Token | Hex | Usage |
|-------|-----|-------|
| `bg-primary` | `#1E1E1E` | Main background |
| `bg-secondary` | `#252526` | Panel backgrounds |
| `bg-sidebar` | `#1B1B1B` | Sidebar background |
| `bg-titlebar` | `#323233` | Title bar background |
| `bg-toolbar` | `#2D2D2D` | Toolbar background |
| `bg-input` | `#3C3C3C` | Input field backgrounds |
| `bg-hover` | `#2A2D2E` | Hover state |
| `bg-selected` | `#094771` | Selected item |
| `bg-active-tab` | `#1E1E1E` | Active tab (matches content bg) |
| `bg-inactive-tab` | `#2D2D2D` | Inactive tab |
| `fg-primary` | `#CCCCCC` | Primary text |
| `fg-secondary` | `#858585` | Muted/secondary text |
| `fg-emphasis` | `#FFFFFF` | Emphasized text |
| `fg-link` | `#4FC1FF` | Clickable links |
| `accent` | `#0078D4` | Selection, focus, primary actions |
| `border` | `#333333` | Panel dividers, borders |
| `border-subtle` | `#2B2B2B` | Subtle dividers |
| `diff-add-bg` | `#1E3A1E` | Added line background |
| `diff-add-text` | `#4EC94E` | Added line text/gutter |
| `diff-del-bg` | `#3A1E1E` | Deleted line background |
| `diff-del-text` | `#F14C4C` | Deleted line text/gutter |
| `diff-hunk-bg` | `#1E1E3A` | Hunk header background |
| `status-bar` | `#007ACC` | Status bar background |

### Branch Lane Colors (10 rotating colors)

```
#4EC9B0  (teal)
#569CD6  (blue)
#C586C0  (purple)
#CE9178  (orange)
#DCDCAA  (yellow)
#D16969  (red)
#4FC1FF  (cyan)
#C8C864  (lime)
#D7BA7D  (gold)
#B5CEA8  (green)
```

### Light Theme

| Token | Hex |
|-------|-----|
| `bg-primary` | `#FFFFFF` |
| `bg-secondary` | `#F3F3F3` |
| `bg-sidebar` | `#F0F0F0` |
| `fg-primary` | `#1E1E1E` |
| `fg-secondary` | `#6B6B6B` |
| `accent` | `#0078D4` |
| `border` | `#E0E0E0` |

---

## Typography

### Platform-Adaptive UI Font

| Platform | Font Family | Fallback |
|----------|-------------|----------|
| macOS | SF Pro Text | -apple-system, system-ui |
| Windows | Segoe UI | system-ui |
| Linux | system-ui | Ubuntu, Cantarell, sans-serif |

### Code / Diff Font

| Usage | Font | Size | Weight |
|-------|------|------|--------|
| Diff content | JetBrains Mono | 13px | 400 |
| Commit SHA | JetBrains Mono | 12px | 400 |
| File paths | JetBrains Mono | 12px | 400 |

### UI Text Sizes

| Element | Size | Weight | Color Token |
|---------|------|--------|-------------|
| Tab title | 13px | 400 | `fg-primary` |
| Toolbar button | 12px | 400 | `fg-primary` |
| Section header | 11px | 600 | `fg-secondary` (uppercase) |
| Sidebar item | 13px | 400 | `fg-primary` |
| Sidebar item (current) | 13px | 700 | `fg-emphasis` |
| Commit message | 13px | 400 | `fg-primary` |
| Author name | 12px | 400 | `fg-secondary` |
| Date | 12px | 400 | `fg-secondary` |
| Status bar | 12px | 400 | `fg-emphasis` |

---

## Theme System Implementation

### FurcateColors (ThemeExtension)

Define a custom `ThemeExtension<FurcateColors>` class containing all color tokens above. This allows accessing colors via `Theme.of(context).extension<FurcateColors>()`.

### FurcateTextStyles (ThemeExtension)

Define text styles as a `ThemeExtension` that adapts per platform (different font families).

### ThemeData Configuration

- Use `ThemeData.dark()` as base for dark theme
- Override: scaffoldBackgroundColor, cardColor, dividerColor, iconTheme
- Register both `FurcateColors` and `FurcateTextStyles` as extensions
- Use `ThemeCubit` (HydratedCubit) to persist and toggle theme mode

---

## Resizable Panel System

All panels use `multi_split_view` or a custom `ResizablePanel` widget:

| Panel Split | Default Ratio | Min | Max | Persist Key |
|-------------|---------------|-----|-----|-------------|
| Sidebar ↔ Content | 220px fixed | 150px | 400px | `sidebar_width` |
| Top ↔ Bottom (commit/detail) | 60% / 40% | 100px | — | `main_split_ratio` |
| Files ↔ Diff (bottom panel) | 30% / 70% | 150px | — | `detail_split_ratio` |

- Store ratios in `PanelLayoutCubit` (HydratedCubit)
- Drag handle: 4px wide, cursor changes to resize cursor on hover
- Double-click handle: reset to default ratio

---

## Context Menus

Context menus appear on right-click throughout the app. Use `super_context_menu` for native-feeling menus.

### Branch Context Menu
- Checkout
- Merge into current branch
- Rebase current branch onto this
- Rename
- Delete
- Copy branch name

### Commit Context Menu
- Checkout commit
- Create branch here
- Create tag here
- Cherry-pick
- Revert
- Reset current branch to here (soft/mixed/hard)
- Copy SHA

### File Context Menu (in diff/staging)
- Stage / Unstage
- Discard changes
- Open in editor
- Copy file path
- Show in file manager

### Remote Branch Context Menu
- Checkout as local branch
- Delete remote branch
- Copy branch name

---

## Animations & Micro-Interactions

| Interaction | Animation | Duration | Curve |
|-------------|-----------|----------|-------|
| Sidebar section expand/collapse | Height + opacity | 150ms | easeInOut |
| Tab switch | Instant (no animation) | 0ms | — |
| Selection change | Background color cross-fade | 100ms | linear |
| Button hover | Background opacity | 100ms | linear |
| Button press | Scale down 0.97x | 50ms | easeIn |
| Loading indicator | Indeterminate progress bar | continuous | — |
| Panel resize | Immediate tracking | 0ms | — |
| Context menu | Platform native animation | — | — |
| Dialog open | Fade + slight scale up | 200ms | easeOut |
| Toast/snackbar | Slide up + fade in | 250ms | easeOut |

---

## Icon System

Use **Codicons** (VS Code's icon font) or custom SVG icons to match Branched's aesthetic:

| Icon | Usage |
|------|-------|
| `git-branch` | Branch items in sidebar |
| `git-merge` | Merge commits in graph |
| `tag` | Tag items in sidebar |
| `archive` | Stash items |
| `remote` | Remote items |
| `file-add` | Added file status |
| `file-symlink-file` | Modified file |
| `file-minus` | Deleted file |
| `arrow-down` | Fetch / Pull buttons |
| `arrow-up` | Push button |
| `gear` | Settings |
| `search` | Search/filter |
| `plus` | New tab, new branch |
| `close` | Close tab, dismiss |

---

## Responsive Considerations

| Window Width | Behavior |
|-------------|----------|
| < 800px | Sidebar auto-collapses to icon-only mode |
| 800–1200px | Default layout |
| > 1200px | Extra space distributed to commit graph |
| Minimum window size | 750 × 500px |
