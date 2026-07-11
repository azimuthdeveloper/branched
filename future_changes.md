# future_changes.md — Handoff: remaining work for the correctness/auth/graph/testing pass

This document hands off an in-progress, multi-part review-and-fix task to the next agent.
Read this whole file before touching code. The working tree already contains substantial
uncommitted changes (described in "Already completed" below). **Do not revert them.**
`git stash` is currently broken in this repo ("Entry 'CLAUDE.md' not uptodate") — don't
rely on stashing to baseline anything.

## The original user request (verbatim intent)

1. Review the project for correctness and implement fixes where possible. It is a
   cross-platform git client (feature target: Fork parity) for macOS/Linux/Windows, with
   lesser functionality on Android.
2. Android behavior: entire git repos openable on device (bare clone), but only smaller
   files editable; when edited, files are downloaded from the repo at that point in time.
3. Authentication must be handled: when the user adds an authenticated repo, a prompt
   must appear so they can authenticate. Cross-platform.
4. The commit graph (merging etc., graphically) is believed incorrect — review/fix.
5. Rename all "Furcate" branding to "Branched".
6. The test suite should comprehensively test the git client via **integration tests that
   click the UI**, against a **small public git repo**.

## Already completed (uncommitted, in working tree)

### 1. Furcate → Branched rename — DONE
- All Dart code: `FurcateTheme`→`BranchedTheme`, `FurcateApp`→`BranchedApp`, UI strings,
  signature fallbacks (`Branched User` / `user@branched.app`), mock emails.
- Platform configs: `macos/Runner/Configs/AppInfo.xcconfig` (bundle id now
  `com.branched.app`), `linux/CMakeLists.txt`, `windows/runner/Runner.rc`.
- `grep -rn "urcate" lib test integration_test` returns 0 hits.

### 2. Commit graph layout — REWRITTEN (needs unit test, see TODO 2)
- `lib/features/commit_graph/graph_layout.dart` fully rewritten. The old algorithm had
  four real bugs: (a) no vertical line on a commit's own lane → linear history rendered
  as disconnected dots; (b) merge curves drawn with inverted geometry (top→center at the
  child's row instead of connecting the dot); (c) spurious full-height straight lines on
  lanes newly allocated in the same row; (d) no lane reclamation (lanes grew forever).
- New algorithm: `lanes: List<String?>` where each slot holds the SHA the lane is waiting
  for; lanes are freed at the commit they point to and reused. Connection semantics are
  documented in the file's doc comment and match the existing painter geometry:
  - `straight` = full-height pass-through at fromLane (fromLane==toLane)
  - `mergeLeft/mergeRight` = enters row top at fromLane, ends at dot (toLane, center);
    fromLane==toLane is the commit's own incoming vertical
  - `branchLeft/branchRight` = leaves dot (fromLane, center) to row bottom at toLane;
    fromLane==toLane is the first-parent continuation
- `lib/features/commit_graph/commit_graph_painter.dart` was left as-is deliberately —
  its geometry already matches these semantics (degenerate cubics render as verticals).
- `lib/features/commit_graph/commit_graph_bloc.dart`: search results are now flattened
  (lane 0, no connections) because a filtered subset can't reuse full-graph edges.
- `lib/git_engine/git_service_impl.dart` `getCommitHistory()`: when `branch == null` it
  now pushes HEAD **plus all local and remote branch tips** onto the RevWalk (Fork-style
  whole-repo graph) instead of only HEAD.

### 3. Authentication + FFI network ops — DONE in engine and UI (needs verification)
- New: `lib/git_engine/credentials_service.dart` — `CredentialsService` with a
  `prompt` hook (`CredentialsPrompt`), per-host in-memory session cache,
  `cachedFor/store/invalidate/requestFor`. Handles scp-style `git@host:` URLs in
  `_hostKey`.
- `lib/git_engine/git_models.dart`: added `GitAuthCredentials` (username/password).
- `lib/git_engine/git_service_impl.dart`:
  - `RealGitService({CredentialsService? credentials})` constructor.
  - `_withAuth(url, action)` — runs the action, detects auth failures via
    `_isAuthError` (message contains authentication/401/403/credential/etc.), prompts
    via `CredentialsService`, retries up to 3 times, rethrows on cancel.
  - `_initialCredentialsFor(url)` — cached creds → `UserPass`; `git@`/`ssh://` URLs →
    `KeypairFromAgent` (cross-platform SSH agent).
  - `cloneRepository` — now git2dart FFI on **all** platforms (previously CLI on
    desktop with creds embedded in URL). `bare: Platform.isAndroid`. Runs inside
    `Isolate.run` so the UI isolate never blocks. Passed username/password are seeded
    into the credentials cache.
  - `fetch` / `push` — rewritten from `git` CLI to git2dart `Remote.lookup` +
    `fetch/push(callbacks: Callbacks(credentials: ...))`, inside `Isolate.run`, wrapped
    in `_withAuth`. Push builds refspec `[+]refs/heads/X:refs/heads/X` from the current
    branch when `branch == null`; throws GitException when detached.
  - `pull` — fetch (FFI, authed) then: bare repos → `_fastForwardBranch` (new method,
    fast-forwards `refs/heads/<short>` to `refs/remotes/<remote>/<short>`, throws
    GitException on divergence); non-bare → `git merge refs/remotes/<remote>/<short>`
    via CLI (desktop-only path, same behavior class as before).
  - `getRemotes/addRemote/removeRemote` — migrated from CLI to FFI (`r.remotes`,
    `Remote.lookup/create/delete`) so they work on Android.
- `lib/core/locator.dart` — registers `CredentialsService`, injects into
  `RealGitService`.
- `lib/main.dart` — `rootNavigatorKey` global, set on `MaterialApp.navigatorKey`;
  `main()` wires `locator<CredentialsService>().prompt` to `showCredentialsDialog`.
- New: `lib/features/auth/credentials_dialog.dart` — `showCredentialsDialog(context,
  url, {failedUsername})`, keys: `auth_username_field`, `auth_password_field`,
  `auth_cancel_button`, `auth_ok_button`. Shows "previous credentials rejected" hint
  when `failedUsername != null`.
- `lib/features/repository/toolbar.dart` — `_triggerSync` no longer swallows errors;
  failures show a SnackBar ("<action> failed: ...").

### 4. Other engine correctness fixes — DONE
- `getStatus`: added `if (delta == nullptr) continue;` (null-deref crash fix).
- `_signatureFor(r, {author})` helper: explicit author → repo/global git config
  (`Signature.defaultSignature`) → fallback `Branched User <user@branched.app>`. Used by
  `createCommit`, `createStash`, `createTag`, `writeAndCommitFile`. Signatures are freed
  in `finally` blocks (they were leaked before).
- `createBranch`, `createCommit`, `createStash`: wrapped in try/finally for FFI frees.
- `getFileContentAtRef`: no longer swallows errors returning `''`. Now throws
  `GitException` for: file not found at revision; file larger than
  `RealGitService.maxEditableFileBytes` (= 1 MiB, the "only smaller files editable on
  Android" gate); binary files. Uses `blob.size` / `blob.isBinary`.
- `lib/features/repository/file_browser_panel.dart`: editor pane now shows the error
  (key `file_browser_file_error`) when a selected file fails to load, instead of falling
  through to an **empty editor with a live "Commit Changes" button** (which could have
  committed an empty file over a binary).
- Dead code removed from impl: `_parseMultiFileDiff`, `_getSubmodulePaths`,
  `_getSubmoduleUrls`, `_RemoteUrls`, `_stdout`.

### 5. Facts established during review (so you don't re-derive them)
- `upgrades.md` is largely stale (describes the pre-FFI CLI engine). macOS Release
  entitlements are fine (network.client present; sandbox disabled anyway).
- Local ops still on git CLI by design for now (desktop-only): merge, abortMerge,
  rebase(+continue/abort), cherryPick, revertCommit, reset — see `_run` which throws
  `GitException` on Android. This is acceptable; Android is browse/edit-only.
- git2dart resolved version is 0.5.3 (`~/.pub-cache/hosted/pub.dev/git2dart-0.5.3`).
- `flutter analyze`: ~73 issues, all pre-existing info/warnings (use_build_context_
  synchronously, withOpacity deprecations, a few unused imports). No errors.

---

## IN-FLIGHT: use-after-free bug (fix this FIRST)

**Symptom:** `flutter test test/bare_repo_flow_test.dart` fails at step 3 —
`getTreeFiles` returns `[]`; direct call shows
`git_error_t.GIT_ERROR_ODB: odb: cannot read object: null OID cannot exist` from
`Commit.lookup` inside `getFileContentAtRef` / `getTreeFiles`.

**Root cause (verified against git2dart 0.5.3 source):** `Reference.target` returns
`Oid(libgit2.git_reference_target(refPtr))` — the `git_oid*` points **into the
reference's native memory**. Freeing the `Reference` (or letting its GC finalizer run
when the Dart wrapper is unreachable) dangles every `Oid` obtained from it. The codebase
repeatedly does `final oid = ref.target; ref.free();` then uses `oid` — worked by luck
before, now deterministic failures. The same hazard applies to *temporary* references
(`r.head.target` with no local variable): the wrapper becomes unreachable immediately
and its finalizer may free the ref before the Oid is consumed.

**Fix pattern:** keep the `Reference` alive until *after* every use of its `Oid` (and of
`oid.sha`), then free. Add this helper to `RealGitService` and use it everywhere a head
Oid is needed transiently:

```dart
/// Runs [action] with the repository HEAD oid, keeping the underlying
/// reference alive for the duration (git2dart Oids point into the ref's
/// native memory — freeing the ref dangles the Oid).
T _withHeadOid<T>(Repository r, T Function(Oid oid) action) {
  final head = r.head;
  try {
    return action(head.target);
  } finally {
    head.free();
  }
}
```

**Sites to fix in `lib/git_engine/git_service_impl.dart`** (line numbers from the last
audit grep; re-grep with `grep -n "r\.head\|\.target" lib/git_engine/git_service_impl.dart`
to re-locate after edits):

Confirmed free-before-use bugs:
1. `getTreeFiles` (~line 1631): `final headRef = r.head; commitOid = headRef.target;
   headRef.free();` then `Commit.lookup(oid: commitOid)`. Keep `headRef` alive until
   after the lookup (declare `Reference? headRef` outside try, free in the existing
   `finally`).
2. `getFileContentAtRef` (~line 1678): identical pattern, identical fix.
3. `createTag` (~lines 1396 and 1424): (a) `targetOid = ... : r.head.target;` uses a
   temporary head ref — hold it in a local, free at end; (b)
   `final ref = Reference.lookup(...); final tagOid = ref.target; ref.free();` then
   `Tag.lookup(oid: tagOid)` **and** `tagOid.sha` in the fallback entity — move
   `ref.free()` to after all uses (finally).
4. `getTags` (~line 1373 region): `final targetOid = ref.target; ref.free();
   Tag.lookup(oid: targetOid)` — free after use. (The lightweight-tag fallback branch
   reads `ref.target.sha` while alive — that one is fine.)
5. `_fastForwardBranch` (~lines 1261–1266) — **introduced by this pass**: `remoteOid`
   used (`.sha`, `Merge.base`, `Reference.create(target: remoteOid)`) after
   `remoteRef.free()`, and `localOid.sha` read after `localRef.free()`. Restructure to
   free both refs only at the end (nested try/finally or free in method-level finally).

GC-finalizer-risk sites (temporary `r.head` with no strong local — fix with
`_withHeadOid` or a held local):
6. `createBranch` (~328): `Commit.lookup(repo: r, oid: r.head.target)`.
7. `getCommitHistory` (~432, ~445): `walker.push(r.head.target)`; (~457): `headSha =
   r.head.target.sha`.
8. `getCommit` (~527): `headSha = r.head.target.sha`.
9. `createCommit` (~552): `parents.add(Commit.lookup(repo: r, oid: r.head.target))`.
10. `unstageFile` (~689) / `unstageAll` (~711): `r.resetDefault(oid: r.head.target, ...)`.
11. `getWorkingDiff` (~764): `Commit.lookup(repo: r, oid: r.head.target)`.

Notes:
- `walker.push(oid)` and similar consume the oid during the call — safe as long as the
  ref wrapper is provably alive across the call (a local variable freed after suffices).
- Patterns like `final sha = b.target.sha; ... b.free();` (branches loops) are safe —
  the String is copied while the ref is alive. Don't churn those.
- `writeAndCommitFile` already looks up the commit *before* freeing the head ref — OK.
- After fixing, `flutter test test/bare_repo_flow_test.dart` must pass (all steps: init
  bare, write+commit, list tree, read content, second file, edit, re-read).

---

## Remaining TODO list (in order)

### TODO 1 — Finish the use-after-free fixes (above) and get `flutter test` green
Also remove the unused import warning in `test/bare_repo_flow_test.dart`
(`git_service.dart`) while you're there if trivial.

### TODO 2 — Unit test for the new graph layout
Create `test/graph_layout_test.dart` (pure Dart, no widgets). Cover at minimum:
- Linear history A→B→C: every non-last row has a `branch*` connection with
  `fromLane == toLane == 0` (own-lane continuation); every non-first row has a `merge*`
  incoming with `fromLane == toLane == 0`; no `straight` connections; all lane 0.
- Merge commit M(parents A,B): M row has two `branch*` connections (one to lane 0, one
  to a new lane 1); B's row (when reached) receives the lane-1 incoming; after B is
  consumed lane 1 is freed and can be reused by a later tip (assert reclamation by
  building a second feature branch after the first merges and checking it gets lane 1
  again, not lane 2).
- Branch point (two children, one parent): the second child's row emits a `branch*`
  edge whose `toLane` is the lane already waiting for the shared parent.
- No spurious `straight` on a lane in the same row where it is allocated.
- Root commit frees its lane (a later unrelated tip reuses lane 0/1 appropriately).
Build `CommitEntity` fixtures directly (see `lib/git_engine/git_models.dart` for
required fields; `MockGitService` has construction examples).

### TODO 3 — Wire welcome-screen clone into auth flow + verify Android bare gating (small)
- `RepositoryManagerBloc` clone (`repository_manager_bloc.dart` ~line 167) calls
  `cloneRepository(url, path)` with no creds — that's now fine (auth prompt happens in
  the engine via `_withAuth`), but confirm the clone dialog surfaces `GitException`
  errors to the user (check `_showCloneRepoDialog` in `welcome_screen.dart` and the
  bloc's error state; add a SnackBar/error text if failures are currently silent).
- Optional (user-intent aligned, low risk): in `welcome_screen.dart` clone dialog, when
  `Platform.isAndroid`, show a one-line note that the repo will be opened in
  browse/edit mode (bare clone, files downloaded on demand).
- Decide on gating the "Files" sidebar tab: currently both "Changes" and "Files" tabs
  render for all repos (`lib/features/sidebar/sidebar.dart` ~lines 682–783). Minimum
  viable: leave as-is (Files works at HEAD everywhere); better: show "Files" only when
  `isBareRepository` is true and hide "Changes" for bare repos (bare repos have no
  working tree, so the staging panel is meaningless there). If you gate it, plumb an
  `isBare` flag through `RepositoryBloc`/`MainWorkspace` (it already knows the repo) —
  do NOT call the service directly from widgets.

### TODO 4 — Comprehensive UI integration test suite against a small public repo
Create `integration_test/public_repo_flow_test.dart`. Requirements from the user:
- Uses a **public but small** repo. Recommended: `https://github.com/git-fixtures/basic.git`
  (~200 KB, stable, has branches `master`/`branch`, tags, known commit
  `6ecf0ef2c2dffb796033e5a02219af86ec6584e5` at master tip). Fallback if unreachable:
  `https://github.com/octocat/Hello-World.git`.
- Tests must drive the real UI (tap buttons, enter text) with `RealGitService` — model
  the structure on `integration_test/real_git_flow_test.dart` (it shows how to register
  the real service + a mocked `FilePickerService` into `get_it` before `pumpWidget`,
  and how `TestRepoBuilder` scenarios are structured; `testing.md` documents the
  scenario matrix).
- Suggested flow (single `testWidgets` or a small group, sharing one clone in a temp
  dir to keep network use down):
  1. Launch app → WelcomeScreen → tap Clone → enter URL + temp path → confirm clone
     completes → MainWorkspace appears (this exercises the new FFI clone + Isolate.run).
  2. Commit graph: expect >0 rows; verify the known master-tip short SHA appears;
     verify at least one merge commit row exists (git-fixtures/basic has merges) — this
     exercises the new layout with real merge topology.
  3. Sidebar: branches listed (master + remote branches); checkout the second branch;
     HEAD indicator moves; graph refreshes.
  4. Create a branch via commit context menu (`onSecondaryTapDown` → use
     `tester.tap(..., buttons: kSecondaryButton)`); verify it appears in sidebar.
  5. Staging: modify a file in the temp clone with `File(...).writeAsStringSync`,
     refresh, expect it in Unstaged; stage it; commit with a message; expect a new graph
     row with that message.
  6. Stash: modify a file, create stash via UI, expect stash listed; pop it back.
  7. Tags: create a tag on HEAD via context menu; verify sidebar shows it.
  8. Fetch via toolbar button (public repo, no auth) — completes without error SnackBar.
  9. Auth dialog unit-level check (no real private repo available): show
     `showCredentialsDialog` directly in a `testWidgets` in `test/` and assert
     field keys + return value + cancel returns null. ALSO test `CredentialsService`
     host-key caching/invalidations in a pure unit test (`test/credentials_service_test.dart`).
- Skip/guard: wrap network-dependent tests so an offline run fails with a clear
  message (e.g. try a `Socket.connect('github.com', 443)` probe in `setUpAll` and
  `markTestSkipped` when unreachable) rather than a confusing timeout.
- Run with: `flutter test -d macos integration_test/public_repo_flow_test.dart`.
  Expect several minutes; clone into `Directory.systemTemp.createTempSync` and delete
  in `tearDownAll`.

### TODO 5 — Full verification pass
1. `flutter analyze` — no NEW warnings vs. the pre-existing ~73 (no errors, and ideally
   clear the unused-import warnings in files this pass touched:
   `file_browser_bloc.dart`, `file_browser_panel.dart`, `welcome_screen.dart`,
   `window_chrome.dart`, `bare_repo_flow_test.dart`, both old integration tests).
2. `flutter test` — all green (bare repo flow, branch merge unit test, widget test,
   new graph layout + credentials tests).
3. `flutter test -d macos integration_test/branch_merge_flow_test.dart` (MockGitService).
4. `flutter test -d macos integration_test/real_git_flow_test.dart` — NOTE: this suite
   predates the engine changes; if it asserts single-branch-only graph content it may
   need updating because `getCommitHistory(branch: null)` now walks ALL branch tips.
   Update assertions, not the engine.
5. `flutter test -d macos integration_test/public_repo_flow_test.dart` (new suite).
6. Optionally build once for macOS (`flutter build macos --debug`) to catch anything
   the analyzer misses.

### TODO 6 — Final report to the user
Summarize: the graph bugs found+fixed (disconnected dots / inverted merge curves /
phantom lines / no lane reuse), the systemic use-after-free class and where it was
fixed, the auth architecture (engine-level retry + session cache + dialog, SSH agent
for ssh URLs, works on all platforms incl. Android), the Android bare-repo gates
(1 MiB size cap, binary rejection, error surfacing instead of empty-editor commit), the
CLI→FFI migration of network + remote ops (Android now fully functional for
clone/fetch/pull-ff/push), the rename, and the new test coverage. Mention what was
deliberately left on CLI (merge/rebase/cherry-pick/revert/reset — desktop-only) and
that `upgrades.md` is stale in places (entitlements item already fixed, several
"missing features" now exist).

## Gotchas for the next agent
- Files in this repo get touched by a formatter/linter between reads occasionally —
  if `Edit` reports "file modified since read", just Read the target region again.
- The pre-existing integration tests import `sidebar_bloc.dart` unused and declare an
  unused `binding` variable — harmless, clean up only if convenient.
- `MockGitService` implements the unchanged `GitService` interface — no updates needed
  unless you add interface methods (avoid; nothing remaining requires it).
- Don't use `git stash` (broken index state); commit nothing unless the user asks.
- `Isolate.run` closures in the engine must only capture sendable values (strings,
  simple objects like `UserPass`) — never `Repository`/`Reference` wrappers.
- When testing `_withAuth` behavior manually, remember credentials are cached per host
  for the session; `invalidate` is called before each re-prompt.
