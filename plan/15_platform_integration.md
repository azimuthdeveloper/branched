# 15 — Platform Integration

## Overview

Furcate targets macOS, Linux, and Windows. While Flutter provides cross-platform UI, each platform requires specific handling for window chrome, native menus, system integration, and visual fidelity.

---

## Window Chrome (Custom Title Bar)

### Why Custom Title Bar

Branched uses a custom title bar that integrates repository tabs directly into the title bar area. We must replicate this using `bitsdojo_window` to hide the system title bar and draw our own.

### Platform-Specific Title Bar Layout

#### macOS

```
┌──────────────────────────────────────────────────────────────────┐
│ [●][●][●]   [ Repo A ][ Repo B ][ + ]                          │
└──────────────────────────────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Traffic lights (●●●) | Left side, 70px reserved space |
| Tabs | Start after traffic lights, center-aligned |
| Drag area | Empty space in title bar enables window dragging |
| Title bar height | 38px (matches native macOS) |
| Traffic light style | Native (use `macos_window_utils` to position) |

#### Windows

```
┌──────────────────────────────────────────────────────────────────┐
│ 🔀 [ Repo A ][ Repo B ][ + ]                        [─][□][✕] │
└──────────────────────────────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| App icon | Left-aligned, 16px |
| Tabs | After icon |
| Window buttons | Right side (minimize, maximize, close) |
| Button style | Use `bitsdojo_window` buttons styled like Fluent UI |
| Title bar height | 32px (matches Windows 11) |
| Snap layouts | Support Windows 11 snap layout on maximize hover |

#### Linux

```
┌──────────────────────────────────────────────────────────────────┐
│ [ Repo A ][ Repo B ][ + ]                            [─][□][✕] │
└──────────────────────────────────────────────────────────────────┘
```

| Element | Spec |
|---------|------|
| Tabs | Left-aligned |
| Window buttons | Right side (follows system preference) |
| Style | GTK-inspired or GNOME-style |
| Title bar height | 34px |
| CSD/SSD | Support both client-side and server-side decorations |

---

## bitsdojo_window Setup

### Per-Platform Configuration

#### macOS (`macos/Runner/MainFlutterWindow.swift`)

- Set `isMovable = true`
- Set title bar to transparent
- Use `macos_window_utils` for:
  - Making title bar transparent
  - Enabling full-size content view
  - Controlling traffic light position
  - Adding vibrancy effects (if desired)

#### Windows (`windows/runner/main.cpp` / `win32_window.cpp`)

- Remove default title bar via `bitsdojo_window`
- Handle `WM_NCHITTEST` for resize borders
- Support Windows 11 rounded corners
- Handle DPI scaling

#### Linux (`linux/my_application.cc`)

- Use `bitsdojo_window` to remove default header bar
- Handle GTK window resize/move
- Support both X11 and Wayland (use appropriate windowing)

---

## Native Menu Bar

### macOS Application Menu

macOS apps are expected to have a native menu bar at the top of the screen:

```
Furcate | File | Edit | View | Repository | Branch | Stash | Window | Help
```

| Menu | Items |
|------|-------|
| **Furcate** | About, Preferences (Cmd+,), Quit (Cmd+Q) |
| **File** | Open Repository (Cmd+O), Clone (Cmd+Shift+N), Close Tab (Cmd+W), Close Window (Cmd+Shift+W) |
| **Edit** | Undo, Redo, Cut, Copy, Paste, Find (Cmd+F) |
| **View** | Toggle Sidebar (Cmd+B), Toggle Command Log, Zoom In/Out, Enter Full Screen |
| **Repository** | Fetch (Cmd+Shift+F), Pull, Push, Stash, Pop, Refresh (Cmd+R) |
| **Branch** | New Branch, Checkout, Merge, Rebase, Delete |
| **Window** | Minimize, Zoom, Tile, Bring All to Front, Tab list |
| **Help** | Documentation, Release Notes, Report Issue |

Implementation: Use `PlatformMenuBar` (Flutter built-in) or platform channels.

### Windows / Linux

- Optionally embed a menu bar below the title bar
- Or use context menus / toolbar buttons only (Branched's approach on Windows)
- Application menu accessible via Alt key (Windows convention)

---

## File Manager Integration

### "Show in File Manager"

| Platform | Command |
|----------|---------|
| macOS | `open -R <path>` (reveals in Finder) |
| Linux | `xdg-open <parent-dir>` |
| Windows | `explorer /select,<path>` |

### "Open in Terminal"

| Platform | Command |
|----------|---------|
| macOS | Open Terminal.app / iTerm2 at repo path |
| Linux | Open gnome-terminal / konsole at repo path |
| Windows | Open cmd.exe / PowerShell / Windows Terminal at repo path |

### "Open in Editor"

- Detect installed editors: VS Code, Sublime, IntelliJ, etc.
- Use configured editor from settings
- `code <path>` for VS Code

---

## System Tray / Dock Integration

### macOS Dock

- Badge app icon with notification count (e.g., incoming commits)
- Dock menu: Recent Repositories

### Windows System Tray (Optional)

- Tray icon for background operations
- Progress notifications for long operations
- Context menu: Open window, Quit

### Linux

- Desktop notification support via `libnotify`
- `.desktop` file for app launcher integration

---

## Notifications

| Platform | API | Usage |
|----------|-----|-------|
| macOS | `NSUserNotification` / UNUserNotificationCenter | Clone complete, push success |
| Windows | Windows Toast Notifications | Clone complete, push success |
| Linux | `libnotify` / D-Bus notifications | Clone complete, push success |

Use Flutter's `local_notifications` package or platform channels.

---

## File Associations

Register the app to handle:

| Association | Purpose |
|-------------|---------|
| `x-scheme-handler/furcate` | Custom URL scheme: `furcate://open?path=/repo` |
| `.git` folders | "Open with Furcate" in file manager context menu |
| `x-scheme-handler/github-mac` | Handle GitHub URLs (optional) |

---

## Platform-Adaptive UI Details

| Element | macOS | Windows | Linux |
|---------|-------|---------|-------|
| Font family | SF Pro Text | Segoe UI | system-ui |
| Scrollbar | Overlay (thin, auto-hide) | Always visible | System default |
| Button style | Rounded, macOS-native feel | Fluent UI inspired | GTK-inspired |
| Dialog style | Sheet (slides from top) | Centered modal | Centered modal |
| Context menu | Native feel | Native feel | GTK-style |
| Tooltip delay | 1.5s (macOS default) | 0.5s (Windows default) | 0.5s |
| Keyboard modifiers | Cmd (⌘) | Ctrl | Ctrl |
| Selection color | System accent | System accent | System accent |

---

## Window State Persistence

Using `window_manager`:

| State | Persisted |
|-------|-----------|
| Window position (x, y) | Yes |
| Window size (w, h) | Yes |
| Maximized state | Yes |
| Full screen state | Yes |
| Which monitor | Yes |

Persist to Hive box `window_state`. Restore on app launch.

---

## Accessibility

| Feature | Implementation |
|---------|---------------|
| Screen reader | Semantics widgets on all interactive elements |
| Keyboard navigation | Full keyboard support, visible focus indicators |
| High contrast | Theme adapts to OS high contrast mode |
| Font scaling | Respect OS font size settings |
| Reduce motion | Disable animations when OS reduce-motion is on |

---

## Performance per Platform

| Concern | macOS | Windows | Linux |
|---------|-------|---------|-------|
| Rendering | Metal (default) | DirectX / Angle | OpenGL / Vulkan |
| GPU acceleration | ✅ Default | ✅ Default | ⚠ May need fallback |
| File watching | FSEvents | ReadDirectoryChangesW | inotify |
| Process spawning | Fast | Slightly slower | Fast |
| Native library loading | `.dylib` | `.dll` | `.so` |

---

## Build & Distribution

| Platform | Package Format | Tool |
|----------|---------------|------|
| macOS | `.dmg` (with `.app` bundle) | `create-dmg`, Xcode archiving |
| Windows | `.msix` or `.exe` installer | MSIX tool or Inno Setup |
| Linux | `.AppImage`, `.deb`, `.rpm`, Snap, Flatpak | `appimage-builder`, `dpkg-deb` |

### Code Signing

| Platform | Requirement |
|----------|------------|
| macOS | Apple Developer ID certificate + notarization |
| Windows | Code signing certificate (EV recommended) |
| Linux | Not required (but GPG signing for packages) |
