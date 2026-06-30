# 10 — Remote Operations

## Overview

Remote operations cover all interactions with remote Git repositories: fetch, pull, push, remote management, and progress tracking. These are network-bound operations that must run in isolates with progress reporting.

---

## Remote Operations UI

### Toolbar Buttons

```
[ ↓ Fetch ]  [ ↓ Pull ▾ ]  [ ↑ Push ▾ ]
```

| Button | Default Action | Dropdown Options |
|--------|---------------|------------------|
| Fetch | Fetch from tracking remote | Fetch All Remotes |
| Pull | Pull from tracking remote (merge) | Pull (Rebase), Pull (FF Only) |
| Push | Push current branch | Push to..., Force Push |

### Progress Indicator

During any remote operation, show progress in the toolbar:

```
[ ↓ Fetching... ██████░░░░ 60%  450/750 objects ]  [ Cancel ]
```

**Progress elements:**
- Operation name (Fetching / Pulling / Pushing)
- Progress bar (determinate when possible)
- Object count (received/total)
- Bytes transferred
- Cancel button

---

## Fetch

### Behavior

```
1. User clicks Fetch (or Cmd+Shift+F)
2. RemoteOpsBloc.Fetch(remote: tracking remote or "origin")
3. GitService.fetch(repo, remote, credentials, onProgress)
   → Runs in isolate
   → Progress via TransferProgress callback
4. On success:
   → Refresh sidebar (remote branches may have new commits)
   → Refresh commit graph (new remote commits appear)
   → Update upstream info (ahead/behind counts)
   → Show "Fetched from origin" notification
5. On auth failure:
   → Prompt for credentials (see 11_authentication.md)
   → Retry with new credentials
6. On network error:
   → Show "Network error: could not reach origin" notification
```

### Fetch All

- Fetches from all configured remotes sequentially
- Shows combined progress
- Reports errors per-remote

### Auto-Fetch

- Optional setting: auto-fetch every N minutes (default: off)
- Configurable interval: 1, 5, 10, 15, 30 minutes
- Runs silently in background
- Only shows notification if new commits are found
- Implementation: Timer in RemoteOpsBloc, guarded by settings

---

## Pull

### Pull Modes

| Mode | Git Equivalent | Description |
|------|---------------|-------------|
| Merge (default) | `git pull` | Fetch + merge |
| Rebase | `git pull --rebase` | Fetch + rebase |
| Fast-forward only | `git pull --ff-only` | Only if FF possible |

### Pull Flow

```
1. User clicks Pull
2. RemoteOpsBloc.Pull(remote, mode)
3. GitService.pull(repo, remote, mode, credentials, onProgress)
   → Fetch phase: shows transfer progress
   → Merge/Rebase phase: shows merge progress
4. Outcomes:
   a. Clean pull → Refresh graph, sidebar, working copy
   b. Merge conflict → Enter conflict resolution mode
   c. Cannot fast-forward → Show error (for FF-only mode)
   d. Dirty working tree → "Stash changes first?" dialog
   e. Auth failure → Credential prompt
   f. Network error → Error notification
```

### Stash Before Pull

If working tree is dirty:

```
┌──────────────────────────────────────────┐
│  Uncommitted Changes Detected       [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  You have uncommitted changes.           │
│  Choose an action:                       │
│                                          │
│  ○ Stash changes, pull, then reapply     │
│  ○ Discard changes and pull              │
│  ○ Cancel                                │
│                                          │
│              [ Cancel ]  [ Continue ]    │
└──────────────────────────────────────────┘
```

---

## Push

### Push Flow

```
1. User clicks Push
2. Pre-push checks:
   a. Any commits to push? (ahead count > 0)
   b. Upstream configured? If not, offer to set upstream
   c. Is current branch pushable? (not detached HEAD)
3. RemoteOpsBloc.Push(remote, branch, force)
4. GitService.push(repo, remote, branch, credentials, onProgress)
5. Outcomes:
   a. Success → Update ahead/behind counts, show notification
   b. Rejected (non-fast-forward) → Offer to pull first or force push
   c. Auth failure → Credential prompt
   d. Network error → Error notification
```

### Set Upstream Dialog

When pushing a branch with no upstream:

```
┌──────────────────────────────────────────┐
│  No Upstream Configured             [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Branch 'feature/login' has no upstream. │
│                                          │
│  Push to:                                │
│  Remote:  [ origin         ▾ ]           │
│  Branch:  [ feature/login    ]           │
│                                          │
│  [✓] Set as upstream tracking branch     │
│                                          │
│              [ Cancel ]  [ Push ]        │
└──────────────────────────────────────────┘
```

### Force Push

```
┌──────────────────────────────────────────┐
│  ⚠ Force Push Warning              [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Force pushing will overwrite the remote │
│  branch. This may cause others to lose   │
│  their work.                             │
│                                          │
│  Branch: feature/login                   │
│  Remote: origin                          │
│                                          │
│         [ Cancel ]  [ Force Push ]       │
└──────────────────────────────────────────┘
```

---

## Remote Management

### Remotes List (in Settings or dedicated view)

```
┌──────────────────────────────────────────────────┐
│  Remotes                                    [+]  │
├──────────────────────────────────────────────────┤
│  origin     https://github.com/user/repo.git     │
│  upstream   https://github.com/org/repo.git      │
└──────────────────────────────────────────────────┘
```

### Add Remote Dialog

```
┌──────────────────────────────────────────┐
│  Add Remote                         [✕]  │
├──────────────────────────────────────────┤
│  Name:  ┌──────────────────────────┐     │
│         │ upstream                  │     │
│         └──────────────────────────┘     │
│  URL:   ┌──────────────────────────┐     │
│         │ https://github.com/...   │     │
│         └──────────────────────────┘     │
│             [ Cancel ]  [ Add ]         │
└──────────────────────────────────────────┘
```

### Remote Context Menu

| Action | Description |
|--------|-------------|
| Fetch | Fetch from this remote |
| Edit URL | Change the remote URL |
| Remove | Delete the remote configuration |
| Copy URL | Copy remote URL to clipboard |

---

## Ahead/Behind Indicators

Show in sidebar and status bar:

```
Sidebar:
  main  ↑2 ↓3        ← 2 ahead, 3 behind upstream

Status bar:
  ● main  ↑2 ↓3  │  origin/main
```

### Calculation

- After each fetch: compare local branch tip with tracking branch
- `ahead`: commits in local not in remote
- `behind`: commits in remote not in local
- Use `GitService.getUpstreamInfo()` which calls `git2dart`'s ahead/behind

---

## Progress Reporting

### TransferProgress Model

```
TransferProgress {
  int totalObjects,
  int receivedObjects,
  int indexedObjects,
  int totalDeltas,
  int indexedDeltas,
  int receivedBytes,
  double percentage,          // calculated: receivedObjects / totalObjects
  String phase,               // "Counting", "Compressing", "Receiving", "Resolving"
}
```

### Progress UI Placement

1. **Toolbar**: Replace the Fetch/Pull/Push button with progress bar
2. **Status bar**: Show operation name + percentage
3. **Tab**: Show spinner on the tab icon

---

## Network Error Handling

| Error | User-Facing Message | Recovery |
|-------|---------------------|----------|
| DNS resolution failure | "Could not resolve host" | Check internet connection |
| Connection refused | "Connection refused" | Check URL and port |
| Connection timeout | "Connection timed out" | Retry later |
| SSL certificate error | "SSL certificate verification failed" | Option to bypass (with warning) |
| Auth failure (HTTP 401/403) | "Authentication failed" | Re-enter credentials |
| SSH host key mismatch | "Host key verification failed" | Show key and ask to trust |
| Remote repository not found | "Repository not found" | Check URL |
| Push rejected | "Push rejected (non-fast-forward)" | Pull first or force push |

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + Shift + F` | Fetch |
| `Cmd/Ctrl + Shift + P` | Pull |
| `Cmd/Ctrl + Shift + U` | Push |
