# 04 — Git Engine (git2dart Integration Layer)

## Overview

The Git Engine is the core abstraction between the Flutter application and the `git2dart` package (Dart bindings for libgit2). It provides a clean, testable, high-level API that the domain layer consumes while hiding all libgit2 complexity.

---

## Why git2dart (libgit2) Over CLI

| Factor | git2dart (libgit2) | System `git` CLI |
|--------|-------------------|------------------|
| Dependency | Bundled with app | Requires user to install git |
| Data format | Structured Dart objects | String output to parse |
| Performance | Direct library calls | Process spawn overhead |
| Auth | Credential callbacks | Relies on credential helpers |
| Cross-platform | Consistent behavior | CLI flags may vary |
| Error handling | Typed exceptions | Exit codes + stderr parsing |
| Testability | Mockable interface | Harder to mock |

**Decision:** Use `git2dart` as the primary engine. Fall back to CLI only for operations libgit2 doesn't support (interactive rebase, specific config).

---

## Architecture

```
┌─────────────────────────┐
│   BLoCs / Use Cases     │   ← Presentation / Domain layers
└───────────┬─────────────┘
            │ calls
┌───────────▼─────────────┐
│      GitService         │   ← High-level API (interface)
│   (GitServiceImpl)      │   ← Implementation using git2dart
└───────────┬─────────────┘
            │ wraps
┌───────────▼─────────────┐
│    GitRepository        │   ← Per-repo wrapper (holds git2dart handle)
└───────────┬─────────────┘
            │ delegates to
┌───────────▼─────────────┐
│      git2dart           │   ← libgit2 Dart bindings
│   (Repository, Commit,  │
│    Branch, Remote, etc.) │
└─────────────────────────┘
            │
┌───────────▼─────────────┐
│   GitCliAdapter         │   ← Fallback for unsupported ops
│   (Process.run)         │
└─────────────────────────┘
```

---

## GitService Interface

The `GitService` is registered as a singleton in `get_it`. All methods return `Future` (async) and use `Either<GitFailure, T>` from `dartz` for error handling.

### Repository Operations

| Method | Return Type | Description |
|--------|-------------|-------------|
| `openRepository(String path)` | `Either<Failure, GitRepo>` | Opens existing repo |
| `cloneRepository(String url, String path, {Credentials? creds, void Function(double)? onProgress})` | `Either<Failure, GitRepo>` | Clones remote repo |
| `initRepository(String path, {bool bare = false})` | `Either<Failure, GitRepo>` | Creates new repo |
| `isGitRepository(String path)` | `bool` | Checks if path is a git repo |
| `disposeRepository(GitRepo repo)` | `void` | Closes handles, stops watchers |

### Branch Operations

| Method | Return Type |
|--------|-------------|
| `getBranches(GitRepo)` | `Either<Failure, List<BranchEntity>>` |
| `getRemoteBranches(GitRepo)` | `Either<Failure, List<BranchEntity>>` |
| `createBranch(GitRepo, String name, {String? startPoint})` | `Either<Failure, BranchEntity>` |
| `deleteBranch(GitRepo, String name, {bool force = false})` | `Either<Failure, Unit>` |
| `renameBranch(GitRepo, String oldName, String newName)` | `Either<Failure, Unit>` |
| `checkoutBranch(GitRepo, String name)` | `Either<Failure, Unit>` |
| `getCurrentBranch(GitRepo)` | `Either<Failure, BranchEntity>` |
| `getUpstreamInfo(GitRepo, String branch)` | `Either<Failure, UpstreamInfo>` |

### Commit Operations

| Method | Return Type |
|--------|-------------|
| `getCommitHistory(GitRepo, {String? branch, int limit = 100, int offset = 0})` | `Either<Failure, List<CommitEntity>>` |
| `getCommit(GitRepo, String sha)` | `Either<Failure, CommitEntity>` |
| `createCommit(GitRepo, String message, {AuthorEntity? author, bool amend = false})` | `Either<Failure, CommitEntity>` |
| `getCommitCount(GitRepo, {String? branch})` | `Either<Failure, int>` |

### Staging / Working Copy Operations

| Method | Return Type |
|--------|-------------|
| `getStatus(GitRepo)` | `Either<Failure, WorkingCopyStatus>` |
| `stageFile(GitRepo, String path)` | `Either<Failure, Unit>` |
| `unstageFile(GitRepo, String path)` | `Either<Failure, Unit>` |
| `stageAll(GitRepo)` | `Either<Failure, Unit>` |
| `unstageAll(GitRepo)` | `Either<Failure, Unit>` |
| `stageHunk(GitRepo, String path, DiffHunkEntity hunk)` | `Either<Failure, Unit>` |
| `discardFile(GitRepo, String path)` | `Either<Failure, Unit>` |
| `discardAll(GitRepo)` | `Either<Failure, Unit>` |

### Diff Operations

| Method | Return Type |
|--------|-------------|
| `getWorkingDiff(GitRepo, String path, {bool staged = false})` | `Either<Failure, FileDiffEntity>` |
| `getCommitDiff(GitRepo, String sha, {String? parentSha})` | `Either<Failure, List<FileDiffEntity>>` |
| `getFileDiffForCommit(GitRepo, String sha, String path)` | `Either<Failure, FileDiffEntity>` |

### Merge / Rebase Operations

| Method | Return Type |
|--------|-------------|
| `merge(GitRepo, String sourceBranch, {MergeStrategy? strategy})` | `Either<Failure, MergeResultEntity>` |
| `rebase(GitRepo, String upstream, {String? onto})` | `Either<Failure, RebaseResultEntity>` |
| `cherryPick(GitRepo, String sha)` | `Either<Failure, CherryPickResultEntity>` |
| `abortMerge(GitRepo)` | `Either<Failure, Unit>` |
| `abortRebase(GitRepo)` | `Either<Failure, Unit>` |
| `continueRebase(GitRepo)` | `Either<Failure, Unit>` |
| `getConflictedFiles(GitRepo)` | `Either<Failure, List<ConflictedFileEntity>>` |

### Remote Operations

| Method | Return Type |
|--------|-------------|
| `getRemotes(GitRepo)` | `Either<Failure, List<RemoteEntity>>` |
| `addRemote(GitRepo, String name, String url)` | `Either<Failure, Unit>` |
| `removeRemote(GitRepo, String name)` | `Either<Failure, Unit>` |
| `fetch(GitRepo, {String? remote, Credentials? creds, void Function(TransferProgress)? onProgress})` | `Either<Failure, Unit>` |
| `pull(GitRepo, {String? remote, PullMode mode, Credentials? creds, void Function(TransferProgress)? onProgress})` | `Either<Failure, PullResultEntity>` |
| `push(GitRepo, {String? remote, String? branch, bool force, Credentials? creds, void Function(TransferProgress)? onProgress})` | `Either<Failure, Unit>` |

### Tag Operations

| Method | Return Type |
|--------|-------------|
| `getTags(GitRepo)` | `Either<Failure, List<TagEntity>>` |
| `createTag(GitRepo, String name, {String? target, String? message})` | `Either<Failure, TagEntity>` |
| `deleteTag(GitRepo, String name)` | `Either<Failure, Unit>` |

### Stash Operations

| Method | Return Type |
|--------|-------------|
| `getStashes(GitRepo)` | `Either<Failure, List<StashEntity>>` |
| `createStash(GitRepo, {String? message, bool includeUntracked = false})` | `Either<Failure, StashEntity>` |
| `applyStash(GitRepo, int index)` | `Either<Failure, Unit>` |
| `dropStash(GitRepo, int index)` | `Either<Failure, Unit>` |
| `popStash(GitRepo, int index)` | `Either<Failure, Unit>` |

### Graph Operations

| Method | Return Type |
|--------|-------------|
| `buildCommitGraph(GitRepo, List<CommitEntity> commits)` | `List<GraphNodeEntity>` |
| `getParentShas(GitRepo, String sha)` | `List<String>` |
| `getMergeBase(GitRepo, String sha1, String sha2)` | `String?` |

---

## Data Models (Domain Entities)

### CommitEntity

```
CommitEntity {
  String sha,
  String shortSha,             // first 7 chars
  String message,
  String summary,              // first line of message
  AuthorEntity author,
  AuthorEntity committer,
  DateTime dateTime,
  List<String> parentShas,
  bool isHead,
  bool isMergeCommit,          // parentShas.length > 1
  List<RefEntity> refs,        // branches/tags pointing to this commit
}
```

### BranchEntity

```
BranchEntity {
  String name,
  String shortName,            // without refs/heads/ prefix
  String tipSha,
  bool isHead,                 // is current branch
  bool isRemote,
  String? trackingBranch,      // upstream tracking ref
  int? ahead,                  // commits ahead of upstream
  int? behind,                 // commits behind upstream
}
```

### RemoteEntity

```
RemoteEntity {
  String name,                 // "origin", "upstream"
  String url,
  String? pushUrl,
  List<String> fetchRefspecs,
}
```

### TagEntity

```
TagEntity {
  String name,
  String sha,
  String? message,             // null for lightweight tags
  bool isAnnotated,
  AuthorEntity? tagger,
  DateTime? tagDate,
}
```

### StashEntity

```
StashEntity {
  int index,
  String message,
  String sha,
  DateTime dateTime,
  AuthorEntity author,
}
```

### FileDiffEntity

```
FileDiffEntity {
  String path,
  String? oldPath,             // for renames
  FileChangeStatus status,     // modified, added, deleted, renamed, copied, conflicted
  List<DiffHunkEntity> hunks,
  bool isBinary,
  int addedLines,
  int deletedLines,
}
```

### DiffHunkEntity

```
DiffHunkEntity {
  int oldStart,
  int oldLines,
  int newStart,
  int newLines,
  String header,               // @@ line
  List<DiffLineEntity> lines,
}
```

### DiffLineEntity

```
DiffLineEntity {
  String content,
  DiffLineOrigin origin,       // context, addition, deletion
  int? oldLineNumber,
  int? newLineNumber,
}
```

### WorkingCopyStatus

```
WorkingCopyStatus {
  List<FileStatusEntity> unstagedFiles,
  List<FileStatusEntity> stagedFiles,
  List<FileStatusEntity> conflictedFiles,
  bool hasChanges,
}
```

### FileStatusEntity

```
FileStatusEntity {
  String path,
  FileChangeStatus status,
  bool isNew,
  bool isRenamed,
  String? oldPath,
}

enum FileChangeStatus { modified, added, deleted, renamed, copied, conflicted, untracked }
```

### GraphNodeEntity

```
GraphNodeEntity {
  String sha,
  int laneIndex,               // which vertical lane (column)
  List<GraphConnectionEntity> connections,
  int colorIndex,              // index into lane color palette
}

GraphConnectionEntity {
  int fromLane,
  int toLane,
  ConnectionType type,
  int colorIndex,
}

enum ConnectionType { straight, mergeLeft, mergeRight, branchLeft, branchRight }
```

### TransferProgress

```
TransferProgress {
  int totalObjects,
  int receivedObjects,
  int indexedObjects,
  int totalDeltas,
  int indexedDeltas,
  int receivedBytes,
  double percentage,            // 0.0–1.0
}
```

---

## Isolate Strategy

Heavy git operations must not block the UI thread.

### Operations That Run in Isolates

| Operation | Reason |
|-----------|--------|
| `cloneRepository` | Network I/O + large data |
| `getCommitHistory` (large repos) | May process thousands of commits |
| `buildCommitGraph` | CPU-intensive DAG layout calculation |
| `getCommitDiff` (large diffs) | Large file diffs can be slow |
| `fetch` / `pull` / `push` | Network I/O |

### Implementation

```
Main Isolate                          Worker Isolate
     │                                      │
     │── SendPort(path, operation) ──────►  │
     │                                      │── Opens new git2dart handle
     │                                      │── Performs operation
     │  ◄── ReceivePort(progress) ─────────│── Sends progress updates
     │  ◄── ReceivePort(result) ───────────│── Sends final result
     │                                      │── Closes handle
```

> [!IMPORTANT]
> `git2dart` `Repository` objects cannot cross isolate boundaries. Each isolate must open its own handle by path.

### Isolate Pool

- Maintain a pool of 2–4 reusable isolates
- Queue operations when all isolates are busy
- Each isolate opens/closes git2dart handles as needed
- Use `compute()` for simple one-shot operations
- Use long-lived isolates for operations with progress reporting

---

## File Watcher

### What to Watch

| Path | Triggers |
|------|----------|
| `.git/HEAD` | Branch checkout |
| `.git/refs/` (recursive) | Branch/tag creation, push, fetch |
| `.git/index` | Stage/unstage operations |
| `.git/MERGE_HEAD` | Merge in progress |
| `.git/REBASE_HEAD` | Rebase in progress |
| Working tree root | File modifications, additions, deletions |

### Implementation

- Use `dart:io` `Directory.watch(recursive: true)` on the repo root
- Filter events to only relevant paths
- Debounce all events by **300ms** (using `rxdart` debounce or `Timer`)
- On change → dispatch `RepositoryBloc.RefreshRepository`
- Ignore `.git/objects/` changes (too noisy, not user-relevant)
- Ignore changes during active operations (flag set by RemoteOpsBloc, etc.)

---

## Error Handling

### GitFailure Hierarchy

```
GitFailure (sealed class)
├── RepositoryNotFound { String path }
├── NotARepository { String path }
├── AuthenticationFailed { String remote, String? message }
├── NetworkError { String message }
├── MergeConflict { List<String> conflictedFiles }
├── BranchAlreadyExists { String name }
├── BranchNotFound { String name }
├── TagAlreadyExists { String name }
├── DirtyWorkingTree { String message }
├── RebaseInProgress { }
├── MergeInProgress { }
├── InvalidOperation { String message }
├── UnknownGitError { String message, Object? originalError }
```

### Error Wrapping

All `git2dart` exceptions are caught in `GitServiceImpl` and mapped to `GitFailure` subtypes:

```
try {
  // git2dart operation
} on LibGit2Exception catch (e) {
  return Left(_mapException(e));
}
```

---

## Fallback CLI Adapter

For operations `libgit2` / `git2dart` doesn't support well:

| Operation | Reason for CLI Fallback |
|-----------|------------------------|
| Interactive rebase | libgit2 has limited rebase support |
| `git log --graph` format | For verifying our graph matches git |
| Complex config operations | libgit2 config API is limited |
| Submodule operations | Partial support in libgit2 |
| Git-Flow commands | Not a git primitive |

### GitCliAdapter

```
GitCliAdapter {
  Future<ProcessResult> run(String repoPath, List<String> args)
  bool isGitInstalled()
  String? getGitVersion()
}
```

- Detect system `git` on startup
- If not available, disable CLI-dependent features gracefully
- Parse stdout/stderr for structured results
- Handle non-zero exit codes as errors

---

## Initialization Flow

```
1. App starts
2. GitService.init() called from AppBloc
   → Verifies git2dart native libraries are loaded
   → Optionally detects system git CLI
3. User opens a repository
   → GitService.openRepository(path)
   → Returns GitRepo handle
   → RepositoryBloc starts file watcher
4. User performs operations
   → All go through GitService methods
   → Heavy ops dispatched to isolates
5. User closes tab
   → GitService.disposeRepository(repo)
   → File watcher stopped
   → git2dart handle freed
```
