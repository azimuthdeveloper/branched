# 09 — Diff Viewer

## Overview

The diff viewer is the right-hand panel that shows file changes. It supports unified and side-by-side (split) views, syntax highlighting, hunk-level staging, and image diffs. This is a complex, performance-critical component.

---

## Display Modes

### Unified Diff

```
┌──────────────────────────────────────────────────────────────┐
│  src/bloc/app_bloc.dart  (Modified)        [Unified|Split]  │
├──────────────────────────────────────────────────────────────┤
│  @@ -12,6 +12,9 @@ class AppBloc extends Bloc {              │
│  12  12 │   final AuthRepository _authRepo;                  │
│  13  13 │                                                    │
│  14  14 │   AppBloc(this._authRepo) : super(AppInitial()) { │
│      15 │ +   on<AppStarted>(_onAppStarted);                │
│      16 │ +   on<AppLogout>(_onAppLogout);                  │
│      17 │ +   on<AppRefresh>(_onAppRefresh);                │
│  15  18 │   }                                                │
│  16  19 │                                                    │
│  17     │ -  void dispose() {                                │
│  18     │ -    super.dispose();                              │
│      20 │ +  @override                                       │
│      21 │ +  Future<void> close() async {                    │
│      22 │ +    await _authRepo.dispose();                    │
│      23 │ +    return super.close();                         │
│  19  24 │   }                                                │
└──────────────────────────────────────────────────────────────┘
```

### Side-by-Side (Split) Diff

```
┌──────────────────────────────┬──────────────────────────────┐
│  OLD (HEAD)                  │  NEW (Working Copy)          │
├──────────────────────────────┼──────────────────────────────┤
│  12 │ final AuthRepository   │  12 │ final AuthRepository   │
│  13 │                        │  13 │                        │
│  14 │ AppBloc(this._authR... │  14 │ AppBloc(this._authR... │
│     │                        │  15 │+on<AppStarted>(_on...) │
│     │                        │  16 │+on<AppLogout>(_onA...) │
│     │                        │  17 │+on<AppRefresh>(_on...) │
│  15 │ }                      │  18 │ }                      │
│  16 │                        │  19 │                        │
│  17 │-void dispose() {       │  20 │+@override              │
│  18 │-  super.dispose();     │  21 │+Future<void> close()   │
│     │                        │  22 │+  await _authRepo...   │
│     │                        │  23 │+  return super.close() │
│  19 │ }                      │  24 │ }                      │
└──────────────────────────────┴──────────────────────────────┘
```

---

## Visual Specification

### Gutter (Line Numbers)

| Element | Spec |
|---------|------|
| Width | ~50px per gutter (old line # + new line #) |
| Font | JetBrains Mono, 12px |
| Color | Muted (`fg-secondary`) |
| Background | Slightly darker than content area |

### Line Content

| Element | Spec |
|---------|------|
| Font | JetBrains Mono, 13px |
| Added line bg | `diff-add-bg` (#1E3A1E dark, #E6FFED light) |
| Added line marker | `+` in gutter, green color |
| Deleted line bg | `diff-del-bg` (#3A1E1E dark, #FFEEF0 light) |
| Deleted line marker | `-` in gutter, red color |
| Context line bg | Transparent (inherits panel bg) |
| Hunk header bg | `diff-hunk-bg` (#1E1E3A dark) |
| Hunk header text | Muted, italic |

### Word-Level Highlighting

Within added/deleted lines, highlight the specific changed words:

```
- final String name = "old_value";
                       ^^^^^^^^^^^ (darker red highlight)
+ final String name = "new_value";
                       ^^^^^^^^^^^ (darker green highlight)
```

- Compare old and new lines word-by-word
- Highlight changed segments with a stronger tint

---

## Diff Toolbar

```
┌──────────────────────────────────────────────────────────────────┐
│  src/bloc/app_bloc.dart  │  +15 −4  │  [Unified] [Split]  │ ⚙  │
└──────────────────────────────────────────────────────────────────┘
```

| Element | Description |
|---------|-------------|
| File path | Full path (monospace font) |
| Stats | Added/deleted line counts (green/red) |
| Mode toggle | Switch between unified and split view |
| Settings gear | Context lines count, word wrap, whitespace options |

### Diff Settings

| Setting | Options | Default |
|---------|---------|---------|
| Context lines | 3, 5, 10, all | 3 |
| Word wrap | On/Off | Off |
| Show whitespace | On/Off | Off |
| Tab size | 2, 4, 8 | 4 |
| Ignore whitespace changes | On/Off | Off |

---

## Syntax Highlighting

Use the `re_highlight` package for syntax-aware coloring.

### Supported Languages (detect from file extension)

| Extension | Language |
|-----------|----------|
| `.dart` | Dart |
| `.js`, `.jsx`, `.ts`, `.tsx` | JavaScript/TypeScript |
| `.py` | Python |
| `.java`, `.kt` | Java/Kotlin |
| `.go` | Go |
| `.rs` | Rust |
| `.c`, `.cpp`, `.h` | C/C++ |
| `.cs` | C# |
| `.rb` | Ruby |
| `.swift` | Swift |
| `.html`, `.xml` | HTML/XML |
| `.css`, `.scss` | CSS |
| `.json` | JSON |
| `.yaml`, `.yml` | YAML |
| `.md` | Markdown |
| `.sql` | SQL |
| `.sh`, `.bash` | Shell |
| (others) | Plain text fallback |

### Highlighting Rules

- Apply syntax highlighting on top of diff coloring
- Added/deleted line backgrounds take precedence
- Token colors adjusted to be visible on both green/red backgrounds
- Use a subset of VS Code's Dark+ theme for token colors

---

## Hunk Actions in Diff

When viewing unstaged changes, each hunk has action buttons:

```
@@ -12,6 +12,8 @@ class AppBloc {           [Stage Hunk ▲] [Discard Hunk ✕]
```

When viewing staged changes:

```
@@ -12,6 +12,8 @@ class AppBloc {           [Unstage Hunk ▼]
```

### Line-Level Staging

- User can select specific lines within a hunk
- Right-click → "Stage Selected Lines" or "Unstage Selected Lines"
- Implementation: construct a partial patch with only the selected lines

---

## Side-by-Side Synchronized Scrolling

For split view, both panels must scroll in sync:

### Implementation

- Use `linked_scroll_controller` package
- Both panels share a `LinkedScrollControllerGroup`
- Vertical scroll is synchronized
- Each panel can scroll horizontally independently (for long lines)

### Line Matching

In split view, empty lines are inserted to keep corresponding lines aligned:

```
OLD                              NEW
12 │ line A                      12 │ line A
13 │ removed line        ←→         │ (empty placeholder)
   │ (empty placeholder) ←→     13 │ added line
14 │ line B                      14 │ line B
```

---

## Image Diff

For image files (`.png`, `.jpg`, `.gif`, `.svg`, `.webp`, `.bmp`):

### Image Diff Modes

| Mode | Description |
|------|-------------|
| Side-by-side | Old image on left, new image on right |
| Swipe | Draggable divider to reveal old/new |
| Onion skin | Overlay with opacity slider |
| Difference | Pixel difference highlighting |

### Image Diff Layout

```
┌───────────────────────┬───────────────────────┐
│                       │                       │
│    OLD IMAGE          │    NEW IMAGE          │
│    (128×128, 24KB)    │    (128×128, 26KB)    │
│                       │                       │
└───────────────────────┴───────────────────────┘
│  [Side-by-Side] [Swipe] [Onion Skin] [Diff]  │
```

### Detection

- Check `FileDiffEntity.isBinary` flag
- Check file extension against known image types
- If binary but not image: show "Binary file changed (size diff)"

---

## Empty States

| Scenario | Display |
|----------|---------|
| No file selected | "Select a file to view changes" centered message |
| File has no diff (unchanged) | "No changes" message |
| Binary file (non-image) | "Binary file changed — 24KB → 26KB" |
| File too large | "File is too large to display inline. Open externally?" |
| New file (all added) | All lines green, no old lines |
| Deleted file (all removed) | All lines red, no new lines |

---

## Performance

### Large Diff Optimization

| File Size | Strategy |
|-----------|----------|
| < 500 lines | Render all lines immediately |
| 500–5000 lines | Virtualized list (only render visible) |
| 5000–50000 lines | Virtualized + lazy syntax highlighting |
| > 50000 lines | Show warning, offer to open externally |

### Rendering

- Use a custom `ListView.builder` for line rendering
- Fixed line height (18–20px) for predictable scrolling
- Syntax highlighting computed once, cached per file
- Word-level diff computed once, cached per hunk

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + D` | Toggle diff mode (unified ↔ split) |
| `]` / `[` | Next / previous hunk |
| `↑` / `↓` | Scroll diff |
| `Cmd/Ctrl + F` | Find in diff |
| `Cmd/Ctrl + G` | Go to line |
