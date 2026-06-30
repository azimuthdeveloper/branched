# 14 — Settings & Configuration

## Overview

The settings system covers user preferences, Git configuration, keyboard shortcuts, and persisted app state. All settings use `HydratedBloc`/`HydratedCubit` for automatic persistence.

---

## Settings Window

Accessed via toolbar gear icon or `Cmd/Ctrl + ,`.

```
┌──────────────────────────────────────────────────────────────────┐
│  Settings                                                   [✕]  │
├──────────────┬───────────────────────────────────────────────────┤
│              │                                                   │
│  General     │  General Settings                                 │
│  Git         │  ─────────────────                                │
│  Appearance  │                                                   │
│  Editor      │  Default clone directory:                         │
│  Shortcuts   │  ┌─────────────────────────────┐ [Browse]         │
│  Advanced    │  │ ~/code                       │                  │
│              │  └─────────────────────────────┘                  │
│              │                                                   │
│              │  [ ] Open last repositories on startup            │
│              │  [ ] Check for updates automatically              │
│              │                                                   │
│              │  Language: [ English              ▾ ]             │
│              │                                                   │
│              │  Terminal application:                             │
│              │  ┌─────────────────────────────┐                  │
│              │  │ Terminal (auto-detect)       │                  │
│              │  └─────────────────────────────┘                  │
│              │                                                   │
└──────────────┴───────────────────────────────────────────────────┘
```

---

## Settings Sections

### General

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Default clone directory | Path | `~/code` | Default path for clone dialog |
| Open last repos on startup | bool | true | Reopen tabs from last session |
| Check for updates | bool | true | Auto-update check |
| Confirm before destructive actions | bool | true | Show confirm dialogs for discard, force push, etc. |
| External diff tool | Path | — | Path to external diff tool (e.g., Beyond Compare) |
| External merge tool | Path | — | Path to external merge tool |
| External editor | Path | auto-detect | Path to code editor (VS Code, etc.) |
| Terminal application | Path | auto-detect | Path to terminal app |

### Git Configuration

| Setting | Git Config Key | Default | Description |
|---------|---------------|---------|-------------|
| User name | `user.name` | — | Committer name |
| User email | `user.email` | — | Committer email |
| Default branch | `init.defaultBranch` | `main` | Default branch for new repos |
| Auto-CRLF | `core.autocrlf` | Platform-dependent | Line ending handling |
| GPG signing | `commit.gpgsign` | false | Sign commits with GPG |
| GPG key | `user.signingkey` | — | GPG key ID |
| Pull mode | `pull.rebase` | false | Default pull strategy |
| Push default | `push.default` | `current` | Push behavior |

**Scope selector:**
- Global (`~/.gitconfig`) — affects all repos
- Repository (`.git/config`) — per-repo overrides

### Appearance

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Theme | enum | System | Light, Dark, System |
| Accent color | Color | `#0078D4` | UI accent color |
| Font size | int | 13 | Base UI font size |
| Code font size | int | 13 | Diff/code font size |
| Code font family | String | JetBrains Mono | Monospace font |
| Show line numbers | bool | true | In diff viewer |
| Tab size | int | 4 | Tab width in diff |
| Date format | enum | Relative | Relative, Absolute, ISO |
| Sidebar width | double | 220 | Persisted sidebar width |

### Editor / Diff

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Diff mode | enum | Unified | Unified, Split |
| Context lines | int | 3 | Lines of context around changes |
| Word wrap | bool | false | Wrap long lines |
| Show whitespace | bool | false | Visualize spaces/tabs |
| Ignore whitespace | bool | false | In diff comparison |
| Syntax highlighting | bool | true | Enable syntax colors |
| Image diff mode | enum | Side-by-side | Side-by-side, Swipe, Onion |

### Keyboard Shortcuts

| Action | Default (macOS) | Default (Win/Linux) | Customizable |
|--------|----------------|---------------------|-------------|
| Commit | `Cmd+Enter` | `Ctrl+Enter` | Yes |
| Stage all | `Cmd+Shift+A` | `Ctrl+Shift+A` | Yes |
| Unstage all | `Cmd+Shift+U` | `Ctrl+Shift+U` | Yes |
| Fetch | `Cmd+Shift+F` | `Ctrl+Shift+F` | Yes |
| Pull | `Cmd+Shift+P` | `Ctrl+Shift+P` | Yes |
| Push | `Cmd+Shift+U` | `Ctrl+Shift+U` | Yes |
| Open repo | `Cmd+O` | `Ctrl+O` | Yes |
| Close tab | `Cmd+W` | `Ctrl+W` | Yes |
| Next tab | `Cmd+Tab` | `Ctrl+Tab` | Yes |
| Quick open | `Cmd+P` | `Ctrl+P` | Yes |
| Command palette | `Cmd+Shift+P` | `Ctrl+Shift+P` | Yes |
| Find in diff | `Cmd+F` | `Ctrl+F` | Yes |
| Toggle sidebar | `Cmd+B` | `Ctrl+B` | Yes |
| Settings | `Cmd+,` | `Ctrl+,` | Yes |

**Shortcut customization UI:**
```
┌────────────────────────────────────────────────┐
│  Action              │  Shortcut               │
├──────────────────────┼─────────────────────────┤
│  Commit              │  ⌘ Enter  [Edit]        │
│  Stage All           │  ⌘ ⇧ A    [Edit]        │
│  Fetch               │  ⌘ ⇧ F    [Edit]        │
│  ...                 │  ...                     │
└──────────────────────┴─────────────────────────┘
│  [Reset to Defaults]                            │
```

### Advanced

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| Auto-fetch interval | int (minutes) | 0 (off) | Periodic background fetch |
| Max commit history | int | 5000 | Max commits to load in graph |
| Show command log | bool | false | Show git commands being executed |
| Enable GPU acceleration | bool | true | Hardware rendering |
| Log level | enum | Warning | Debug, Info, Warning, Error |
| Proxy settings | String | System | HTTP proxy for remote ops |

---

## Persistence Strategy

### What Gets Persisted

| Data | Storage | Mechanism |
|------|---------|-----------|
| App settings | Hive box `settings` | `HydratedCubit` |
| Theme preference | Hive box `settings` | `ThemeCubit` (Hydrated) |
| Recent repositories | Hive box `recent_repos` | `RecentRepositoriesCubit` (Hydrated) |
| Panel layout | Hive box `layout` | `PanelLayoutCubit` (Hydrated) |
| Open tabs (session) | Hive box `session` | `RepositoryManagerBloc` (Hydrated) |
| Column widths | Hive box `layout` | Per-component cubits |
| Keyboard shortcuts | Hive box `shortcuts` | `KeyboardShortcutCubit` (Hydrated) |
| Window position/size | Hive box `window` | `window_manager` persistence |
| Credentials | OS Keychain | `flutter_secure_storage` |

### Storage Location

```
macOS:   ~/Library/Application Support/com.furcate.furcate/
Linux:   ~/.local/share/com.furcate.furcate/
Windows: %APPDATA%\com.furcate\furcate\
```

---

## Git Config Reading/Writing

### Implementation

```
GitConfigService {
  // Read global config
  Future<String?> getGlobal(String key)
  Future<void> setGlobal(String key, String value)

  // Read repo-specific config
  Future<String?> getRepo(GitRepo repo, String key)
  Future<void> setRepo(GitRepo repo, String key, String value)

  // List all config entries
  Future<Map<String, String>> listAll({bool global = false})
}
```

- Use `git2dart`'s Config API for reading/writing git configuration
- Support both global and repository-level config
- For unsupported config keys: fall back to CLI `git config`

---

## Command Log (Transparency Feature)

Branched has a feature showing the actual git commands being run. Replicate this:

```
┌──────────────────────────────────────────────────┐
│  Command Log                                [✕]  │
├──────────────────────────────────────────────────┤
│  [12:34:05] git fetch origin                     │
│  [12:34:03] git status                           │
│  [12:33:58] git commit -m "feat: add login"      │
│  [12:33:55] git add src/login.dart                │
│  [12:33:50] git checkout feature/auth             │
└──────────────────────────────────────────────────┘
```

- Even though we use git2dart (not CLI), log the equivalent git commands
- Helpful for users learning git
- Toggle via settings or `Cmd/Ctrl + Shift + L`
- Stored in circular buffer (last 200 commands)
