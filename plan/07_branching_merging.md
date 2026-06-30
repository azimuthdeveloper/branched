# 07 — Branching, Merging & Conflict Resolution

## Overview

This component covers all branch operations (create, delete, rename, checkout), merge strategies, rebase workflows, cherry-pick, and the merge conflict resolution UI.

---

## Branch Operations

### Create Branch

**Dialog:**
```
┌──────────────────────────────────────┐
│  Create New Branch              [✕]  │
├──────────────────────────────────────┤
│                                      │
│  Branch name:                        │
│  ┌──────────────────────────────┐    │
│  │ feature/my-new-feature        │    │
│  └──────────────────────────────┘    │
│                                      │
│  Based on:                           │
│  ┌──────────────────────────────┐    │
│  │ main                    [▼]  │    │
│  └──────────────────────────────┘    │
│                                      │
│  [✓] Checkout after creating         │
│                                      │
│              [ Cancel ]  [ Create ]  │
└──────────────────────────────────────┘
```

**Validation:**
- Name must not be empty
- Name must not contain: spaces, `~`, `^`, `:`, `?`, `*`, `[`, `\`, `..`
- Name must not already exist
- Show real-time validation feedback

**Flow:**
1. `BranchOperationBloc.CreateBranch(name, startPoint, checkout)`
2. `GitService.createBranch(repo, name, startPoint)`
3. If checkout: `GitService.checkoutBranch(repo, name)`
4. Refresh SidebarBloc and CommitGraphBloc

### Delete Branch

**Confirmation dialog:**
```
Delete branch "feature/old-feature"?
This action cannot be undone.
[ ] Force delete (even if not fully merged)
                    [ Cancel ]  [ Delete ]
```

**Rules:**
- Cannot delete the current branch (show error)
- Warn if branch is not fully merged (offer force delete)
- Remote branches: offer to delete from remote too

### Rename Branch

- Inline rename in sidebar (double-click) or dialog
- Same validation rules as create
- Cannot rename to an existing branch name

### Checkout Branch

**Triggers:**
- Double-click branch in sidebar
- Right-click → Checkout
- Branch dropdown in toolbar
- Click on branch label in commit graph

**Pre-checkout Checks:**
- If working tree is dirty:
  ```
  You have uncommitted changes.
  [ Stash and Checkout ] [ Discard and Checkout ] [ Cancel ]
  ```
- If there are conflicts: block checkout

---

## Merge Operations

### Merge Dialog

```
┌──────────────────────────────────────────┐
│  Merge Branch                       [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Merge:  feature/login                   │
│  Into:   main  (current branch)          │
│                                          │
│  Strategy:                               │
│  ○ Merge commit (--no-ff)                │
│  ○ Fast-forward if possible (default)    │
│  ○ Squash                                │
│                                          │
│  Commit message (for merge commit):      │
│  ┌──────────────────────────────────┐    │
│  │ Merge branch 'feature/login'     │    │
│  └──────────────────────────────────┘    │
│                                          │
│                  [ Cancel ]  [ Merge ]   │
└──────────────────────────────────────────┘
```

### Merge Strategies

| Strategy | git2dart method | Description |
|----------|----------------|-------------|
| Normal (merge commit) | `merge()` with `--no-ff` | Always creates merge commit |
| Fast-forward | `merge()` | FF if possible, merge commit otherwise |
| Fast-forward only | `merge()` with `--ff-only` | Fails if FF not possible |
| Squash | `merge()` with squash flag | Squash all commits into one |

### Merge Flow

```
1. User selects source branch (sidebar drag-drop, context menu, or dialog)
2. BranchOperationBloc.MergeBranch(source, strategy)
3. GitService.merge(repo, source, strategy)
4. Outcomes:
   a. Success (clean merge) → Refresh graph, show success notification
   b. Fast-forward → Update branch pointer, refresh
   c. Conflicts → Enter conflict resolution mode
   d. Error → Show error dialog
```

---

## Rebase Operations

### Rebase Dialog

```
┌──────────────────────────────────────────┐
│  Rebase Branch                      [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Rebase:  feature/login  (current)       │
│  Onto:    main                           │
│                                          │
│  This will replay your commits on top    │
│  of 'main'. History will be rewritten.   │
│                                          │
│                 [ Cancel ]  [ Rebase ]   │
└──────────────────────────────────────────┘
```

### Rebase Flow

```
1. BranchOperationBloc.RebaseBranch(upstream, onto)
2. GitService.rebase(repo, upstream, onto)
3. Outcomes:
   a. Success → Refresh graph
   b. Conflict on a commit → Enter conflict resolution mode
      - Show which commit caused the conflict
      - User resolves, then "Continue Rebase"
      - Repeat until all commits replayed
   c. User aborts → GitService.abortRebase()
```

### In-Progress Indicators

When a merge or rebase is in progress, show a persistent banner:

```
┌──────────────────────────────────────────────────────────────┐
│ ⚠ MERGE IN PROGRESS — 2 conflicted files remaining          │
│ [ Resolve Conflicts ]  [ Abort Merge ]  [ Continue Merge ]  │
└──────────────────────────────────────────────────────────────┘
```

---

## Interactive Rebase (Visual)

Branched's signature feature — a visual interactive rebase editor.

### UI

```
┌─────────────────────────────────────────────────────┐
│  Interactive Rebase                            [✕]  │
├─────────────────────────────────────────────────────┤
│  Rebasing onto: main                                │
│                                                      │
│  ┌────────┬──────────────────────────────────────┐  │
│  │ Action │ Commit                                │  │
│  ├────────┼──────────────────────────────────────┤  │
│  │ [Pick▼]│ a1b2c3d Add login screen             │  │
│  │ [Pick▼]│ d4e5f6a Add password validation      │  │
│  │ [Sqsh▼]│ b7c8d9e Fix typo in login            │  │
│  │ [Pick▼]│ e0f1a2b Add forgot password flow     │  │
│  │ [Drop▼]│ c3d4e5f Debug logging (remove)       │  │
│  └────────┴──────────────────────────────────────┘  │
│                                                      │
│  Actions: Pick | Squash | Fixup | Edit | Drop        │
│  Drag commits to reorder                             │
│                                                      │
│                    [ Cancel ]  [ Start Rebase ]      │
└─────────────────────────────────────────────────────┘
```

### Actions

| Action | Description |
|--------|-------------|
| Pick | Use commit as-is |
| Squash | Combine with previous commit (keep both messages) |
| Fixup | Combine with previous commit (discard this message) |
| Edit | Pause rebase at this commit for editing |
| Reword | Change commit message only |
| Drop | Remove this commit |

### Implementation

> [!IMPORTANT]
> libgit2 has limited interactive rebase support. This feature will likely need the **GitCliAdapter** fallback, generating a rebase-todo file and executing `git rebase -i` with a custom `GIT_SEQUENCE_EDITOR`.

---

## Cherry-Pick

**Flow:**
1. Right-click commit in graph → Cherry-Pick
2. `BranchOperationBloc.CherryPick(sha)`
3. `GitService.cherryPick(repo, sha)`
4. On conflict: enter conflict resolution mode
5. On success: refresh graph (new commit appears on current branch)

---

## Conflict Resolution UI

When a merge or rebase produces conflicts, the app enters **Conflict Resolution Mode**.

### Conflict Mode Layout

```
┌────────────────────────────────────────────────────────────────────┐
│ ⚠ MERGE CONFLICT — Merging 'feature/login' into 'main'           │
│ [ Abort Merge ]                                    [ Commit Merge]│
├──────────────┬─────────────────────────────────────────────────────┤
│ Conflicted:  │  ┌─────────────────┬─────────────────┐             │
│  ! main.dart │  │   OURS (main)   │  THEIRS (feat)  │             │
│  ! utils.dart│  │                 │                  │             │
│ Resolved:    │  │  code line 1    │  code line 1     │             │
│  ✓ config.y  │  │ <<<< conflict   │ <<<< conflict    │             │
│              │  │  our version    │  their version   │             │
│              │  │ >>>>            │ >>>>             │             │
│              │  │                 │                  │             │
│              │  └─────────────────┴─────────────────┘             │
│              │                                                     │
│              │  [ Accept Ours ] [ Accept Theirs ] [ Manual Edit ]  │
└──────────────┴─────────────────────────────────────────────────────┘
```

### Conflict Resolution Options (per file)

| Option | Description |
|--------|-------------|
| Accept Ours | Use the current branch's version entirely |
| Accept Theirs | Use the incoming branch's version entirely |
| Manual Edit | Open the conflicted file in a three-way diff editor |
| Open in External Editor | Launch system default editor |
| Mark as Resolved | After manual edits, mark the conflict as resolved |

### Three-Way Diff (Advanced)

```
┌──────────────┬──────────────┬──────────────┐
│    BASE      │    OURS      │   THEIRS     │
│  (common     │  (current    │  (incoming   │
│   ancestor)  │   branch)    │   branch)    │
└──────────────┴──────────────┴──────────────┘
```

### Conflict Resolution Flow

```
1. Merge/rebase produces conflicts
2. ConflictResolutionBloc.LoadConflicts
3. For each conflicted file:
   a. User views diff
   b. Chooses resolution strategy
   c. ConflictResolutionBloc.MarkResolved(path)
4. When all resolved:
   a. For merge: CommitFormCubit.submit() with merge message
   b. For rebase: BranchOperationBloc.ContinueRebase
5. At any point: user can Abort
```

---

## Reset Operations

### Reset Dialog (from commit context menu → "Reset to Here")

```
┌──────────────────────────────────────────┐
│  Reset 'main' to a1b2c3d           [✕]  │
├──────────────────────────────────────────┤
│                                          │
│  Reset mode:                             │
│  ○ Soft  — Keep all changes staged       │
│  ○ Mixed — Keep all changes unstaged     │
│  ○ Hard  — Discard all changes           │
│                                          │
│  ⚠ Hard reset will permanently discard   │
│  all uncommitted changes!                │
│                                          │
│                 [ Cancel ]  [ Reset ]    │
└──────────────────────────────────────────┘
```

---

## Git-Flow Support

### Available Git-Flow Operations (context menu)

| Operation | Command |
|-----------|---------|
| Init Git-Flow | Configure branch naming conventions |
| Start Feature | Create feature/xxx branch from develop |
| Finish Feature | Merge feature into develop, delete branch |
| Start Release | Create release/xxx branch from develop |
| Finish Release | Merge into main + develop, create tag |
| Start Hotfix | Create hotfix/xxx branch from main |
| Finish Hotfix | Merge into main + develop, create tag |

> [!NOTE]
> Git-Flow operations are composite (multiple git operations). Implement using a `GitFlowService` that orchestrates multiple `GitService` calls.

---

## Edge Cases

| Scenario | Handling |
|----------|----------|
| Merge with no changes | Show "Already up to date" message |
| Delete branch that is checked out | Block with error message |
| Force-push after rebase | Warn user, require confirmation |
| Merge into detached HEAD | Block with error message |
| Rebase with uncommitted changes | Require stash or commit first |
| Multiple ongoing operations | Queue operations, show busy indicator |
