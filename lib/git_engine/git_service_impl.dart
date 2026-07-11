import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:git2dart_binaries/git2dart_binaries.dart' hide Libgit2;
import 'package:git2dart/git2dart.dart';
import 'git_models.dart';
import 'git_service.dart';

/// Thrown when a git command exits with a non-zero exit code.
class GitException implements Exception {
  final String command;
  final int exitCode;
  final String stderr;

  GitException(this.command, this.exitCode, this.stderr);

  @override
  String toString() => 'GitException: `$command` exited with $exitCode\n$stderr';
}

/// A [GitService] implementation that delegates to the system `git` binary
/// via [Process.run].
class RealGitService implements GitService {
  RealGitService() {
    try {
      Libgit2.ownerValidation = false;
    } catch (e) {
      // Ignore or log.
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  CommitEntity _mapCommit(Commit c, {bool isHead = false, List<RefEntity> refs = const []}) {
    final authorSig = c.author;
    final committerSig = c.committer;
    final parents = c.parents.map((p) => p.sha).toList();

    return CommitEntity(
      sha: c.oid.sha,
      shortSha: c.oid.sha.substring(0, 7),
      message: c.message,
      summary: c.summary,
      author: AuthorEntity(name: authorSig.name, email: authorSig.email),
      committer: AuthorEntity(name: committerSig.name, email: committerSig.email),
      dateTime: DateTime.fromMillisecondsSinceEpoch(c.time * 1000),
      parentShas: parents,
      isHead: isHead,
      isMergeCommit: parents.length > 1,
      refs: refs,
    );
  }

  FileChangeStatus _mapStatusFlags(Set<GitStatus> flags, {required bool staged}) {
    if (staged) {
      if (flags.contains(GitStatus.indexNew)) return FileChangeStatus.added;
      if (flags.contains(GitStatus.indexDeleted)) return FileChangeStatus.deleted;
      if (flags.contains(GitStatus.indexRenamed)) return FileChangeStatus.renamed;
      return FileChangeStatus.modified;
    } else {
      if (flags.contains(GitStatus.wtNew)) return FileChangeStatus.untracked;
      if (flags.contains(GitStatus.wtDeleted)) return FileChangeStatus.deleted;
      if (flags.contains(GitStatus.wtRenamed)) return FileChangeStatus.renamed;
      return FileChangeStatus.modified;
    }
  }

  /// Runs a git command in [workingDirectory] and returns stdout as a string.
  /// Throws [GitException] when the process exits with a non-zero code, unless
  /// [allowFailure] is true (in which case it returns the [ProcessResult]).
  Future<ProcessResult> _run(
    List<String> args, {
    required String workingDirectory,
    bool allowFailure = false,
  }) async {
    if (Platform.isAndroid) {
      throw GitException(
        'git ${args.join(' ')}',
        127,
        'Native Git CLI operations (such as cloning) are not supported on Android. Direct local file editing and viewing is available.',
      );
    }

    final result = await Process.run(
      'git',
      ['-c', 'core.quotepath=false', ...args],
      workingDirectory: workingDirectory,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (!allowFailure && result.exitCode != 0) {
      throw GitException(
        'git ${args.join(' ')}',
        result.exitCode,
        (result.stderr as String).trim(),
      );
    }
    return result;
  }

  String _stdout(ProcessResult r) => (r.stdout as String);

  String _safeRefSha(Pointer<git_reference> refPtr) {
    if (refPtr == nullptr) return '';
    try {
      final type = libgit2.git_reference_type(refPtr);
      
      if (type == git_reference_t.GIT_REFERENCE_DIRECT) {
        final oidPtr = libgit2.git_reference_target(refPtr);
        if (oidPtr != nullptr) {
          return Oid(oidPtr).sha;
        }
      } else if (type == git_reference_t.GIT_REFERENCE_SYMBOLIC) {
        Pointer<git_reference> resolved = nullptr;
        using((arena) {
          final resolvedOut = arena<Pointer<git_reference>>();
          final error = libgit2.git_reference_resolve(resolvedOut, refPtr);
          if (error == 0) {
            resolved = resolvedOut.value;
          }
        });
        if (resolved != nullptr) {
          final oidPtr = libgit2.git_reference_target(resolved);
          String sha = '';
          if (oidPtr != nullptr) {
            sha = Oid(oidPtr).sha;
          }
          libgit2.git_reference_free(resolved);
          return sha;
        }
      }
    } catch (_) {}
    return '';
  }

  /// Runs [action] with the repository HEAD oid, keeping the underlying
  /// reference alive for the duration.
  ///
  /// git2dart [Oid]s returned by [Reference.target] point into the reference's
  /// native memory — freeing (or GC-finalizing) the ref dangles the Oid.
  T _withHeadOid<T>(Repository r, T Function(Oid oid) action) {
    final head = r.head;
    try {
      return action(head.target);
    } finally {
      head.free();
    }
  }

  /// SHA of HEAD while the reference is still alive. Returns null when HEAD
  /// is unborn or otherwise unreadable.
  String? _headSha(Repository r) {
    try {
      return _withHeadOid(r, (oid) => oid.sha);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Repository Operations
  // ---------------------------------------------------------------------------

  @override
  Future<GitRepo> openRepository(String path) async {
    final repo = Repository.open(path);
    final name = p.basename(path);
    repo.free();
    return GitRepo(path: path, name: name);
  }

  @override
  Future<bool> isGitRepository(String path) async {
    try {
      final repo = Repository.open(path);
      repo.free();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<GitRepo> cloneRepository(
    String url,
    String path, {
    String? username,
    String? password,
    void Function(double)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      onProgress?.call(0.0);
      final r = Repository.clone(
        url: url,
        localPath: path,
        bare: true,
        callbacks: Callbacks(
          transferProgress: (progress) {
            final total = progress.totalObjects;
            final indexed = progress.indexedObjects;
            if (total > 0) {
              onProgress?.call(indexed / total);
            }
          },
          credentials: (username != null && password != null)
              ? UserPass(username: username, password: password)
              : null,
        ),
      );
      final name = p.basename(path);
      r.free();
      return GitRepo(path: path, name: name);
    }
    onProgress?.call(0.0);
    String effectiveUrl = url;
    if (username != null && password != null) {
      final uri = Uri.parse(url);
      effectiveUrl = uri.replace(userInfo: '$username:$password').toString();
    }
    await _run(
      ['clone', '--progress', effectiveUrl, path],
      workingDirectory: Directory.current.path,
    );
    onProgress?.call(1.0);
    final name = p.basename(path);
    return GitRepo(path: path, name: name);
  }

  @override
  Future<GitRepo> initRepository(String path, {bool bare = false}) async {
    final repo = Repository.init(path: path, bare: bare);
    final name = p.basename(path);
    repo.free();
    return GitRepo(path: path, name: name);
  }

  @override
  void disposeRepository(GitRepo repo) {
    // Nothing to dispose.
  }

  // ---------------------------------------------------------------------------
  // Branch Operations
  // ---------------------------------------------------------------------------

  @override
  Future<List<BranchEntity>> getBranches(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final list = <BranchEntity>[];
    try {
      for (final b in r.branchesLocal) {
        list.add(BranchEntity(
          name: b.name,
          shortName: b.name,
          tipSha: _safeRefSha(b.pointer),
          isHead: b.isHead,
          isRemote: false,
        ));
        b.free();
      }
    } catch (_) {}
    r.free();
    return list;
  }

  @override
  Future<List<BranchEntity>> getRemoteBranches(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final list = <BranchEntity>[];
    try {
      for (final b in r.branchesRemote) {
        list.add(BranchEntity(
          name: b.name,
          shortName: b.name,
          tipSha: _safeRefSha(b.pointer),
          isHead: b.isHead,
          isRemote: true,
        ));
        b.free();
      }
    } catch (_) {}
    r.free();
    return list;
  }

  @override
  Future<BranchEntity> createBranch(
    GitRepo repo,
    String name, {
    String? startPoint,
  }) async {
    final r = Repository.open(repo.path);
    final Commit target;
    if (startPoint != null) {
      target = Commit.lookup(repo: r, oid: Oid.fromSHA(r, startPoint));
    } else {
      target = _withHeadOid(r, (oid) => Commit.lookup(repo: r, oid: oid));
    }
    try {
      final branch = Branch.create(repo: r, name: name, target: target);
      final entity = BranchEntity(
        name: branch.name,
        shortName: branch.name,
        tipSha: target.oid.sha,
        isHead: false,
        isRemote: false,
      );
      branch.free();
      return entity;
    } finally {
      target.free();
      r.free();
    }
  }

  @override
  Future<void> deleteBranch(
    GitRepo repo,
    String name, {
    bool force = false,
  }) async {
    final r = Repository.open(repo.path);
    Branch.delete(repo: r, name: name);
    r.free();
  }

  @override
  Future<void> renameBranch(GitRepo repo, String oldName, String newName) async {
    final r = Repository.open(repo.path);
    Branch.rename(repo: r, oldName: oldName, newName: newName);
    r.free();
  }

  @override
  Future<void> checkoutBranch(GitRepo repo, String name) async {
    final r = Repository.open(repo.path);
    try {
      // Accept "main", "refs/heads/main", or remote-style names.
      final fullRefName = name.startsWith('refs/')
          ? name
          : name.contains('/')
              ? 'refs/remotes/$name'
              : 'refs/heads/$name';

      // Point HEAD at the branch (attached), then update the worktree.
      r.setHead(fullRefName);
      Checkout.reference(
        repo: r,
        name: fullRefName,
        strategy: {GitCheckout.force, GitCheckout.recreateMissing},
      );
    } finally {
      r.free();
    }
  }

  @override
  Future<BranchEntity> getCurrentBranch(GitRepo repo) async {
    final r = Repository.open(repo.path);
    try {
      // Unborn HEAD: branch name exists symbolically but has no commits yet.
      if (r.isBranchUnborn) {
        try {
          final headFile = File(p.join(repo.path, '.git', 'HEAD'));
          // Bare repos store HEAD at repo/HEAD rather than repo/.git/HEAD.
          final headPath = headFile.existsSync()
              ? headFile.path
              : p.join(repo.path, 'HEAD');
          final raw = File(headPath).readAsStringSync().trim();
          // "ref: refs/heads/master"
          final match = RegExp(r'^ref:\s*(.+)$').firstMatch(raw);
          final refName = match?.group(1)?.trim() ?? 'refs/heads/main';
          final short = refName.startsWith('refs/heads/')
              ? refName.substring('refs/heads/'.length)
              : refName;
          r.free();
          return BranchEntity(
            name: refName,
            shortName: short,
            tipSha: '',
            isHead: true,
            isRemote: false,
          );
        } catch (_) {
          r.free();
          return const BranchEntity(
            name: 'refs/heads/main',
            shortName: 'main',
            tipSha: '',
            isHead: true,
            isRemote: false,
          );
        }
      }

      final head = r.head;
      try {
        return BranchEntity(
          name: head.name,
          shortName: head.shorthand,
          tipSha: _safeRefSha(head.pointer),
          isHead: true,
          isRemote: false,
        );
      } finally {
        head.free();
        r.free();
      }
    } catch (_) {
      r.free();
      return const BranchEntity(
        name: 'refs/heads/main',
        shortName: 'main',
        tipSha: '',
        isHead: true,
        isRemote: false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Commit Operations
  // ---------------------------------------------------------------------------

  @override
  Future<List<CommitEntity>> getCommitHistory(
    GitRepo repo, {
    String? branch,
    int limit = 100,
    int offset = 0,
  }) async {
    final r = Repository.open(repo.path);
    final walker = RevWalk(r);
    walker.sorting({GitSort.topological, GitSort.time});

    try {
      if (branch != null) {
        // Accept a branch name, full ref, or raw commit SHA.
        try {
          final refName = branch.startsWith('refs/') ? branch : 'refs/heads/$branch';
          final ref = Reference.lookup(repo: r, name: refName);
          try {
            walker.push(ref.target);
          } finally {
            ref.free();
          }
        } catch (_) {
          // Treat as SHA / any rev that Oid.fromSHA can resolve.
          walker.push(Oid.fromSHA(r, branch));
        }
      } else {
        // Fork-style whole-repo graph: walk HEAD plus every branch tip.
        var pushed = false;
        try {
          _withHeadOid(r, (oid) {
            walker.push(oid);
            pushed = true;
          });
        } catch (_) {}
        try {
          for (final b in r.branchesLocal) {
            try {
              walker.push(b.target);
            } catch (_) {}
            b.free();
          }
          for (final b in r.branchesRemote) {
            try {
              walker.push(b.target);
            } catch (_) {}
            b.free();
          }
          pushed = true;
        } catch (_) {}
        if (!pushed) {
          walker.free();
          r.free();
          return [];
        }
      }
    } catch (_) {
      try {
        _withHeadOid(r, walker.push);
      } catch (_) {
        walker.free();
        r.free();
        return [];
      }
    }

    final headSha = _headSha(r);

    final refsMap = <String, List<RefEntity>>{};
    try {
      for (final b in r.branchesLocal) {
        final sha = _safeRefSha(b.pointer);
        refsMap.putIfAbsent(sha, () => []).add(RefEntity(
          name: b.name,
          type: 'local',
        ));
        b.free();
      }
      for (final b in r.branchesRemote) {
        final sha = _safeRefSha(b.pointer);
        final parts = b.name.split('/');
        final remoteName = parts.isNotEmpty ? parts.first : null;
        refsMap.putIfAbsent(sha, () => []).add(RefEntity(
          name: b.name,
          type: 'remote',
          remote: remoteName,
        ));
        b.free();
      }
      for (final tagName in r.tags) {
        try {
          final ref = Reference.lookup(repo: r, name: 'refs/tags/$tagName');
          final sha = _safeRefSha(ref.pointer);
          ref.free();
          refsMap.putIfAbsent(sha, () => []).add(RefEntity(
            name: tagName,
            type: 'tag',
          ));
        } catch (_) {}
      }
    } catch (_) {}

    final commits = <CommitEntity>[];
    try {
      final walkCommits = walker.walk();
      final start = offset;
      final end = (offset + limit < walkCommits.length) ? offset + limit : walkCommits.length;

      for (int i = start; i < end; i++) {
        final c = walkCommits[i];
        final sha = c.oid.sha;
        commits.add(_mapCommit(
          c,
          isHead: sha == headSha,
          refs: refsMap[sha] ?? const [],
        ));
      }

      for (final c in walkCommits) {
        c.free();
      }
    } catch (_) {}

    walker.free();
    r.free();
    return commits;
  }

  @override
  Future<CommitEntity> getCommit(GitRepo repo, String sha) async {
    final r = Repository.open(repo.path);
    final commit = Commit.lookup(repo: r, oid: Oid.fromSHA(r, sha));
    final headSha = _headSha(r);
    final entity = _mapCommit(commit, isHead: sha == headSha);
    commit.free();
    r.free();
    return entity;
  }

  @override
  Future<CommitEntity> createCommit(
    GitRepo repo,
    String message, {
    AuthorEntity? author,
    bool amend = false,
  }) async {
    final r = Repository.open(repo.path);
    final index = r.index;
    final treeOid = index.writeTree();
    final tree = Tree.lookup(repo: r, oid: treeOid);

    final signatureName = author?.name ?? 'Furcate User';
    final signatureEmail = author?.email ?? 'user@furcate.app';
    final signature = Signature.create(
      name: signatureName,
      email: signatureEmail,
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );

    final parents = <Commit>[];
    try {
      parents.add(_withHeadOid(r, (oid) => Commit.lookup(repo: r, oid: oid)));
    } catch (_) {}

    final commitOid = Commit.create(
      repo: r,
      updateRef: 'HEAD',
      message: message,
      author: signature,
      committer: signature,
      tree: tree,
      parents: parents,
    );

    final commit = Commit.lookup(repo: r, oid: commitOid);
    final entity = _mapCommit(commit, isHead: true);

    commit.free();
    for (final p in parents) {
      p.free();
    }
    tree.free();
    index.free();
    r.free();

    return entity;
  }

  // ---------------------------------------------------------------------------
  // Staging / Working Copy
  // ---------------------------------------------------------------------------

  @override
  Future<WorkingCopyStatus> getStatus(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final staged = <FileStatusEntity>[];
    final unstaged = <FileStatusEntity>[];
    final conflicted = <FileStatusEntity>[];

    using((arena) {
      final out = arena<Pointer<git_status_list>>();
      final opts = arena<git_status_options>();
      
      libgit2.git_status_options_init(opts, 1);
      
      // GIT_STATUS_OPT_INCLUDE_UNTRACKED = 1
      // GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS = 2
      // GIT_STATUS_OPT_RENAMES_HEAD_TO_INDEX = 4
      // GIT_STATUS_OPT_RENAMES_INDEX_TO_WORKDIR = 8
      opts.ref.flags = 1 | 2 | 4 | 8;
      
      final error = libgit2.git_status_list_new(out, r.pointer, opts);
      if (error == 0) {
        final count = libgit2.git_status_list_entrycount(out.value);
        for (var i = 0; i < count; i++) {
          final entry = libgit2.git_status_byindex(out.value, i);
          if (entry == nullptr) continue;
          
          var delta = entry.ref.index_to_workdir;
          if (entry.ref.head_to_index != nullptr) {
            delta = entry.ref.head_to_index;
          }
          if (delta == nullptr) continue;
          
          final isRenamed = (delta.ref.flags & 4) != 0;
          final pathPtr = isRenamed ? delta.ref.new_file.path : delta.ref.old_file.path;
          if (pathPtr == nullptr) continue;
          final filePath = pathPtr.cast<Utf8>().toDartString();
              
          final statusAsInt = entry.ref.statusAsInt;
          final statusFlags = GitStatus.values
              .skip(1)
              .where((e) => (statusAsInt & e.value) != 0)
              .toSet();
              
          // Staged
          if (statusFlags.contains(GitStatus.indexNew) ||
              statusFlags.contains(GitStatus.indexModified) ||
              statusFlags.contains(GitStatus.indexDeleted) ||
              statusFlags.contains(GitStatus.indexRenamed) ||
              statusFlags.contains(GitStatus.indexTypeChange)) {
            staged.add(FileStatusEntity(
              path: filePath,
              status: _mapStatusFlags(statusFlags, staged: true),
              isNew: statusFlags.contains(GitStatus.indexNew),
              isRenamed: statusFlags.contains(GitStatus.indexRenamed),
            ));
          }

          // Unstaged / Working Tree
          if (statusFlags.contains(GitStatus.wtNew) ||
              statusFlags.contains(GitStatus.wtModified) ||
              statusFlags.contains(GitStatus.wtDeleted) ||
              statusFlags.contains(GitStatus.wtTypeChange) ||
              statusFlags.contains(GitStatus.wtRenamed)) {
            unstaged.add(FileStatusEntity(
              path: filePath,
              status: _mapStatusFlags(statusFlags, staged: false),
              isNew: statusFlags.contains(GitStatus.wtNew),
              isRenamed: statusFlags.contains(GitStatus.wtRenamed),
            ));
          }

          // Conflicted
          if (statusFlags.contains(GitStatus.conflicted)) {
            conflicted.add(FileStatusEntity(
              path: filePath,
              status: FileChangeStatus.conflicted,
            ));
          }
        }
        libgit2.git_status_list_free(out.value);
      }
    });

    r.free();
    return WorkingCopyStatus(
      stagedFiles: staged,
      unstagedFiles: unstaged,
      conflictedFiles: conflicted,
    );
  }

  @override
  Future<void> stageFile(GitRepo repo, String path) async {
    final r = Repository.open(repo.path);
    final index = r.index;
    index.add(path);
    index.write();
    index.free();
    r.free();
  }

  @override
  Future<void> unstageFile(GitRepo repo, String path) async {
    final r = Repository.open(repo.path);
    try {
      _withHeadOid(r, (oid) => r.resetDefault(oid: oid, pathspec: [path]));
    } catch (_) {}
    r.free();
  }

  @override
  Future<void> stageAll(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final index = r.index;
    final statusMap = r.status;
    for (final path in statusMap.keys) {
      index.add(path);
    }
    index.write();
    index.free();
    r.free();
  }

  @override
  Future<void> unstageAll(GitRepo repo) async {
    final r = Repository.open(repo.path);
    try {
      _withHeadOid(r, (oid) => r.resetDefault(oid: oid, pathspec: ['*']));
    } catch (_) {}
    r.free();
  }

  @override
  Future<void> discardFile(GitRepo repo, String path) async {
    final r = Repository.open(repo.path);
    Checkout.head(
      repo: r,
      paths: [path],
      strategy: {GitCheckout.force},
    );
    r.free();
  }

  @override
  Future<void> discardAll(GitRepo repo) async {
    final r = Repository.open(repo.path);
    Checkout.head(
      repo: r,
      strategy: {GitCheckout.force},
    );
    r.free();
  }

  Future<List<String>> discardAllPreview(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final statusMap = r.status;
    final list = statusMap.entries
        .where((e) => e.value.contains(GitStatus.wtNew) || e.value.contains(GitStatus.wtModified))
        .map((e) => e.key)
        .toList();
    r.free();
    return list;
  }

  // ---------------------------------------------------------------------------
  // Diff
  // ---------------------------------------------------------------------------

  @override
  Future<FileDiffEntity> getWorkingDiff(
    GitRepo repo,
    String path, {
    bool staged = false,
  }) async {
    final r = Repository.open(repo.path);
    final index = r.index;
    
    Diff diff;
    if (staged) {
      try {
        final headCommit = _withHeadOid(
          r,
          (oid) => Commit.lookup(repo: r, oid: oid),
        );
        try {
          diff = Diff.treeToIndex(repo: r, tree: headCommit.tree, index: index);
        } finally {
          headCommit.free();
        }
      } catch (_) {
        // Initial repository, diff against empty index
        diff = Diff.indexToWorkdir(repo: r, index: index);
      }
    } else {
      diff = Diff.indexToWorkdir(repo: r, index: index);
    }

    int deltaIndex = -1;
    for (var i = 0; i < diff.deltas.length; i++) {
      final delta = diff.deltas[i];
      if (delta.newFile.path == path || delta.oldFile.path == path) {
        deltaIndex = i;
        break;
      }
    }

    if (deltaIndex == -1) {
      index.free();
      diff.free();
      r.free();
      return FileDiffEntity(
        path: path,
        status: FileChangeStatus.modified,
        hunks: const [],
        isBinary: false,
        addedLines: 0,
        deletedLines: 0,
      );
    }

    final patch = Patch.fromDiff(diff: diff, index: deltaIndex);
    final patchText = patch.text;
    
    final entity = _parseSingleFileDiff(patchText, fallbackPath: path);
    
    patch.free();
    diff.free();
    index.free();
    r.free();
    return entity;
  }

  @override
  Future<List<FileDiffEntity>> getCommitDiff(GitRepo repo, String sha) async {
    final r = Repository.open(repo.path);
    final commit = Commit.lookup(repo: r, oid: Oid.fromSHA(r, sha));
    
    Diff diff;
    if (commit.parents.isNotEmpty) {
      final parentOid = commit.parents.first;
      final parentCommit = Commit.lookup(repo: r, oid: parentOid);
      diff = Diff.treeToTree(repo: r, oldTree: parentCommit.tree, newTree: commit.tree);
      parentCommit.free();
    } else {
      diff = Diff.treeToTree(repo: r, oldTree: null, newTree: commit.tree);
    }

    final diffs = <FileDiffEntity>[];
    for (var i = 0; i < diff.deltas.length; i++) {
      final patch = Patch.fromDiff(diff: diff, index: i);
      final path = diff.deltas[i].newFile.path;
      diffs.add(_parseSingleFileDiff(patch.text, fallbackPath: path));
      patch.free();
    }

    diff.free();
    commit.free();
    r.free();
    return diffs;
  }

  @override
  Future<FileDiffEntity> getFileDiffForCommit(
    GitRepo repo,
    String sha,
    String path,
  ) async {
    final r = Repository.open(repo.path);
    final commit = Commit.lookup(repo: r, oid: Oid.fromSHA(r, sha));
    
    Diff diff;
    if (commit.parents.isNotEmpty) {
      final parentOid = commit.parents.first;
      final parentCommit = Commit.lookup(repo: r, oid: parentOid);
      diff = Diff.treeToTree(repo: r, oldTree: parentCommit.tree, newTree: commit.tree);
      parentCommit.free();
    } else {
      diff = Diff.treeToTree(repo: r, oldTree: null, newTree: commit.tree);
    }

    int deltaIndex = -1;
    for (var i = 0; i < diff.deltas.length; i++) {
      final d = diff.deltas[i];
      if (d.newFile.path == path || d.oldFile.path == path) {
        deltaIndex = i;
        break;
      }
    }

    if (deltaIndex == -1) {
      diff.free();
      commit.free();
      r.free();
      return FileDiffEntity(
        path: path,
        status: FileChangeStatus.modified,
        hunks: const [],
        isBinary: false,
        addedLines: 0,
        deletedLines: 0,
      );
    }

    final patch = Patch.fromDiff(diff: diff, index: deltaIndex);
    final entity = _parseSingleFileDiff(patch.text, fallbackPath: path);

    patch.free();
    diff.free();
    commit.free();
    r.free();
    return entity;
  }

  // ---- Diff parsing helpers ----

  /// Parse a unified diff that contains one or more files.
  List<FileDiffEntity> _parseMultiFileDiff(String raw) {
    if (raw.trim().isEmpty) return [];

    // Split on "diff --git" headers.
    final fileSections = raw.split(RegExp(r'^(?=diff --git )', multiLine: true));
    final diffs = <FileDiffEntity>[];
    for (final section in fileSections) {
      if (section.trim().isEmpty) continue;
      diffs.add(_parseSingleFileDiff(section));
    }
    return diffs;
  }

  /// Parse a single file's unified diff output.
  FileDiffEntity _parseSingleFileDiff(String raw, {String? fallbackPath}) {
    if (raw.contains('Submodule ')) {
      final lines = raw.split('\n');
      final hunks = <DiffHunkEntity>[];
      final diffLines = <DiffLineEntity>[];
      String header = 'Submodule changes';
      int added = 0;
      int deleted = 0;

      for (final line in lines) {
        if (line.startsWith('Submodule ')) {
          header = line;
        } else if (line.trim().startsWith('>')) {
          added++;
          diffLines.add(DiffLineEntity(
            content: line,
            origin: DiffLineOrigin.addition,
            newLineNumber: added,
          ));
        } else if (line.trim().startsWith('<')) {
          deleted++;
          diffLines.add(DiffLineEntity(
            content: line,
            origin: DiffLineOrigin.deletion,
            oldLineNumber: deleted,
          ));
        } else if (line.trim().isNotEmpty) {
          diffLines.add(DiffLineEntity(
            content: line,
            origin: DiffLineOrigin.context,
          ));
        }
      }

      if (diffLines.isNotEmpty) {
        hunks.add(DiffHunkEntity(
          oldStart: 1,
          oldLines: deleted,
          newStart: 1,
          newLines: added,
          header: header,
          lines: diffLines,
        ));
      }

      return FileDiffEntity(
        path: fallbackPath ?? '',
        status: FileChangeStatus.modified,
        hunks: hunks,
        isBinary: false,
        addedLines: added,
        deletedLines: deleted,
      );
    }

    final lines = raw.split('\n');

    // Extract path from "diff --git a/foo b/foo" or "+++ b/foo"
    String? path;
    String? oldPath;
    bool isBinary = false;
    FileChangeStatus status = FileChangeStatus.modified;

    for (final line in lines) {
      if (line.startsWith('diff --git ')) {
        final match = RegExp(r'^diff --git a/(.*?) b/(.*)$').firstMatch(line);
        if (match != null) {
          oldPath = match.group(1);
          path = match.group(2);
        }
      } else if (line.startsWith('+++ b/')) {
        path = line.substring(6);
      } else if (line.startsWith('+++ /dev/null')) {
        status = FileChangeStatus.deleted;
      } else if (line.startsWith('--- /dev/null')) {
        status = FileChangeStatus.added;
      } else if (line.startsWith('--- a/')) {
        oldPath = line.substring(6);
      } else if (line.startsWith('Binary files')) {
        isBinary = true;
      } else if (line.startsWith('new file mode')) {
        status = FileChangeStatus.added;
      } else if (line.startsWith('deleted file mode')) {
        status = FileChangeStatus.deleted;
      } else if (line.startsWith('rename from ')) {
        oldPath = line.substring('rename from '.length);
        status = FileChangeStatus.renamed;
      } else if (line.startsWith('rename to ')) {
        path = line.substring('rename to '.length);
        status = FileChangeStatus.renamed;
      }
    }

    path ??= fallbackPath ?? '';

    if (isBinary) {
      return FileDiffEntity(
        path: path,
        oldPath: (oldPath != null && oldPath != path) ? oldPath : null,
        status: status,
        hunks: const [],
        isBinary: true,
        addedLines: 0,
        deletedLines: 0,
      );
    }

    // Parse hunks
    final hunks = <DiffHunkEntity>[];
    int addedTotal = 0;
    int deletedTotal = 0;

    List<DiffLineEntity>? currentLines;
    int? hunkOldStart;
    int? hunkOldLines;
    int? hunkNewStart;
    int? hunkNewLines;
    String? hunkHeader;
    int oldLineNum = 0;
    int newLineNum = 0;

    void flushHunk() {
      if (currentLines != null && hunkOldStart != null) {
        hunks.add(DiffHunkEntity(
          oldStart: hunkOldStart,
          oldLines: hunkOldLines!,
          newStart: hunkNewStart!,
          newLines: hunkNewLines!,
          header: hunkHeader!,
          lines: currentLines!,
        ));
      }
      currentLines = null;
    }

    for (final line in lines) {
      if (line.startsWith('@@')) {
        flushHunk();
        final hunkMatch =
            RegExp(r'^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@(.*)$').firstMatch(line);
        if (hunkMatch != null) {
          hunkOldStart = int.parse(hunkMatch.group(1)!);
          hunkOldLines = int.parse(hunkMatch.group(2) ?? '1');
          hunkNewStart = int.parse(hunkMatch.group(3)!);
          hunkNewLines = int.parse(hunkMatch.group(4) ?? '1');
          hunkHeader = line;
          currentLines = [];
          oldLineNum = hunkOldStart;
          newLineNum = hunkNewStart;
        }
        continue;
      }

      if (currentLines == null) continue;

      if (line.startsWith('+')) {
        currentLines!.add(DiffLineEntity(
          content: line,
          origin: DiffLineOrigin.addition,
          newLineNumber: newLineNum,
        ));
        newLineNum++;
        addedTotal++;
      } else if (line.startsWith('-')) {
        currentLines!.add(DiffLineEntity(
          content: line,
          origin: DiffLineOrigin.deletion,
          oldLineNumber: oldLineNum,
        ));
        oldLineNum++;
        deletedTotal++;
      } else if (line.startsWith(' ') || line.isEmpty) {
        // Context line (or empty trailing line in the diff).
        if (line.isNotEmpty || currentLines!.isNotEmpty) {
          currentLines!.add(DiffLineEntity(
            content: line,
            origin: DiffLineOrigin.context,
            oldLineNumber: oldLineNum,
            newLineNumber: newLineNum,
          ));
          oldLineNum++;
          newLineNum++;
        }
      }
      // Ignore "\\ No newline at end of file" and other lines.
    }
    flushHunk();

    return FileDiffEntity(
      path: path,
      oldPath: (oldPath != null && oldPath != path) ? oldPath : null,
      status: status,
      hunks: hunks,
      isBinary: false,
      addedLines: addedTotal,
      deletedLines: deletedTotal,
    );
  }

  // ---------------------------------------------------------------------------
  // Merge
  // ---------------------------------------------------------------------------

  @override
  Future<void> merge(GitRepo repo, String sourceBranch) async {
    await _run(['merge', sourceBranch], workingDirectory: repo.path);
  }

  @override
  Future<void> abortMerge(GitRepo repo) async {
    await _run(['merge', '--abort'], workingDirectory: repo.path);
  }

  @override
  Future<void> rebase(GitRepo repo, String branch) async {
    await _run(['rebase', branch], workingDirectory: repo.path);
  }

  @override
  Future<void> continueRebase(GitRepo repo) async {
    await _run(['rebase', '--continue'], workingDirectory: repo.path);
  }

  @override
  Future<void> abortRebase(GitRepo repo) async {
    await _run(['rebase', '--abort'], workingDirectory: repo.path);
  }

  @override
  Future<void> cherryPick(GitRepo repo, String sha) async {
    await _run(['cherry-pick', sha], workingDirectory: repo.path);
  }

  @override
  Future<void> revertCommit(GitRepo repo, String sha) async {
    await _run(['revert', sha], workingDirectory: repo.path);
  }

  @override
  Future<void> reset(GitRepo repo, String sha, {required String mode}) async {
    await _run(['reset', '--$mode', sha], workingDirectory: repo.path);
  }

  // ---------------------------------------------------------------------------
  // Remotes
  // ---------------------------------------------------------------------------

  @override
  Future<List<RemoteEntity>> getRemotes(GitRepo repo) async {
    final result = await _run(['remote', '-v'], workingDirectory: repo.path);
    final lines = _stdout(result).trim().split('\n');
    // Lines look like: "origin\thttps://… (fetch)"
    final remoteMap = <String, _RemoteUrls>{};
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final name = parts[0];
      final url = parts[1];
      final isFetch = line.contains('(fetch)');
      final entry = remoteMap.putIfAbsent(name, () => _RemoteUrls());
      if (isFetch) {
        entry.fetchUrl = url;
      } else {
        entry.pushUrl = url;
      }
    }
    return remoteMap.entries.map((e) {
      final fetchUrl = e.value.fetchUrl ?? e.value.pushUrl ?? '';
      final pushUrl = e.value.pushUrl;
      return RemoteEntity(
        name: e.key,
        url: fetchUrl,
        pushUrl: (pushUrl != null && pushUrl != fetchUrl) ? pushUrl : null,
      );
    }).toList();
  }

  @override
  Future<void> addRemote(GitRepo repo, String name, String url) async {
    await _run(['remote', 'add', name, url], workingDirectory: repo.path);
  }

  @override
  Future<void> removeRemote(GitRepo repo, String name) async {
    await _run(['remote', 'remove', name], workingDirectory: repo.path);
  }

  @override
  Future<void> fetch(
    GitRepo repo, {
    String? remote,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.0);
    final args = ['fetch', '--progress'];
    if (remote != null) args.add(remote);
    await _run(args, workingDirectory: repo.path);
    onProgress?.call(1.0);
  }

  @override
  Future<void> pull(
    GitRepo repo, {
    String? remote,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.0);
    final args = ['pull', '--progress'];
    if (remote != null) args.add(remote);
    await _run(args, workingDirectory: repo.path);
    onProgress?.call(1.0);
  }

  @override
  Future<void> push(
    GitRepo repo, {
    String? remote,
    String? branch,
    bool force = false,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.0);
    final args = ['push', '--progress', '--recurse-submodules=on-demand'];
    if (force) args.add('--force');
    if (remote != null) args.add(remote);
    if (branch != null) args.add(branch);
    await _run(args, workingDirectory: repo.path);
    onProgress?.call(1.0);
  }

  // ---------------------------------------------------------------------------
  // Tags
  // ---------------------------------------------------------------------------

  @override
  Future<List<TagEntity>> getTags(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final tags = <TagEntity>[];
    try {
      for (final tagName in r.tags) {
        final ref = Reference.lookup(repo: r, name: 'refs/tags/$tagName');
        try {
          // Annotated tags peel to a Tag object; lightweight tags point at a commit.
          try {
            final tag = Tag.lookup(repo: r, oid: ref.target);
            try {
              tags.add(TagEntity(
                name: tag.name,
                sha: tag.targetOid.sha,
                message: tag.message,
                isAnnotated: true,
              ));
            } finally {
              tag.free();
            }
          } catch (_) {
            tags.add(TagEntity(
              name: tagName,
              sha: ref.target.sha,
              message: null,
              isAnnotated: false,
            ));
          }
        } finally {
          ref.free();
        }
      }
    } catch (_) {}
    r.free();
    return tags;
  }

  @override
  Future<TagEntity> createTag(
    GitRepo repo,
    String name, {
    String? target,
    String? message,
  }) async {
    final r = Repository.open(repo.path);
    Reference? headRef;
    try {
      final Oid targetOid;
      if (target != null) {
        targetOid = Oid.fromSHA(r, target);
      } else {
        headRef = r.head;
        targetOid = headRef.target;
      }

      if (message != null) {
        final signature = Signature.create(
          name: 'Furcate User',
          email: 'user@furcate.app',
          time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        try {
          Tag.createAnnotated(
            repo: r,
            tagName: name,
            target: targetOid,
            targetType: GitObject.commit,
            tagger: signature,
            message: message,
            force: true,
          );
        } finally {
          signature.free();
        }
      } else {
        Tag.createLightweight(
          repo: r,
          tagName: name,
          target: targetOid,
          targetType: GitObject.commit,
          force: true,
        );
      }

      final ref = Reference.lookup(repo: r, name: 'refs/tags/$name');
      try {
        try {
          final tag = Tag.lookup(repo: r, oid: ref.target);
          try {
            return TagEntity(
              name: tag.name,
              sha: tag.targetOid.sha,
              message: tag.message,
              isAnnotated: true,
            );
          } finally {
            tag.free();
          }
        } catch (_) {
          return TagEntity(
            name: name,
            sha: ref.target.sha,
            message: null,
            isAnnotated: false,
          );
        }
      } finally {
        ref.free();
      }
    } finally {
      headRef?.free();
      r.free();
    }
  }

  @override
  Future<void> deleteTag(GitRepo repo, String name) async {
    final r = Repository.open(repo.path);
    Tag.delete(repo: r, tagName: name);
    r.free();
  }

  // ---------------------------------------------------------------------------
  // Stashes
  // ---------------------------------------------------------------------------

  @override
  Future<List<StashEntity>> getStashes(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final stashes = <StashEntity>[];
    try {
      final list = Stash.list(r);
      for (final s in list) {
        stashes.add(StashEntity(
          index: s.index,
          message: s.message,
          sha: s.oid.sha,
          dateTime: DateTime.now(),
        ));
      }
    } catch (_) {}
    r.free();
    return stashes;
  }

  @override
  Future<StashEntity> createStash(
    GitRepo repo, {
    String? message,
    bool includeUntracked = false,
  }) async {
    final r = Repository.open(repo.path);
    final signature = Signature.create(
      name: 'Furcate User',
      email: 'user@furcate.app',
      time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    try {
      final flags = {
        GitStash.defaults,
        if (includeUntracked) GitStash.includeUntracked,
      };
      final oid = Stash.create(
        repo: r,
        stasher: signature,
        message: message,
        flags: flags,
      );
      return StashEntity(
        index: 0,
        message: message ?? 'Stash',
        sha: oid.sha,
        dateTime: DateTime.now(),
      );
    } finally {
      signature.free();
      r.free();
    }
  }

  @override
  Future<void> applyStash(GitRepo repo, int index) async {
    final r = Repository.open(repo.path);
    Stash.apply(repo: r, index: index);
    r.free();
  }

  @override
  Future<void> dropStash(GitRepo repo, int index) async {
    final r = Repository.open(repo.path);
    Stash.drop(repo: r, index: index);
    r.free();
  }

  @override
  Future<void> popStash(GitRepo repo, int index) async {
    final r = Repository.open(repo.path);
    Stash.pop(repo: r, index: index);
    r.free();
  }

  // ---------------------------------------------------------------------------
  // Submodule Operations
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> _getSubmodulePaths(String repoPath) async {
    final result = await _run(
      ['config', '--file', '.gitmodules', '--get-regexp', 'path'],
      workingDirectory: repoPath,
      allowFailure: true,
    );
    if (result.exitCode != 0) return {};
    final lines = LineSplitter.split(result.stdout as String);
    final map = <String, String>{}; // name -> path
    for (final line in lines) {
      final match = RegExp(r'^submodule\.(.+)\.path\s+(.+)$').firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        final path = match.group(2)!;
        map[name] = path;
      }
    }
    return map;
  }

  Future<Map<String, String>> _getSubmoduleUrls(String repoPath) async {
    final result = await _run(
      ['config', '--file', '.gitmodules', '--get-regexp', 'url'],
      workingDirectory: repoPath,
      allowFailure: true,
    );
    if (result.exitCode != 0) return {};
    final lines = LineSplitter.split(result.stdout as String);
    final map = <String, String>{}; // name -> url
    for (final line in lines) {
      final match = RegExp(r'^submodule\.(.+)\.url\s+(.+)$').firstMatch(line);
      if (match != null) {
        final name = match.group(1)!;
        final url = match.group(2)!;
        map[name] = url;
      }
    }
    return map;
  }

  @override
  Future<List<SubmoduleEntity>> getSubmodules(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final submodules = <SubmoduleEntity>[];
    try {
      final paths = Submodule.list(r);
      for (final p in paths) {
        try {
          final sub = Submodule.lookup(repo: r, name: p);
          String headSha = '';
          final hOid = sub.headOid;
          if (hOid != null && hOid.pointer != nullptr) {
            headSha = hOid.sha;
          } else {
            final iOid = sub.indexOid;
            if (iOid != null && iOid.pointer != nullptr) {
              headSha = iOid.sha;
            }
          }
          
          final statusSet = sub.status();
          SubmoduleStatus status = SubmoduleStatus.clean;
          if (statusSet.contains(GitSubmoduleStatus.workdirUninitialized)) {
            status = SubmoduleStatus.uninitialized;
          } else if (statusSet.contains(GitSubmoduleStatus.workdirModified) || 
                     statusSet.contains(GitSubmoduleStatus.indexModified) || 
                     statusSet.contains(GitSubmoduleStatus.smWorkdirModified) ||
                     statusSet.contains(GitSubmoduleStatus.workdirIndexModified)) {
            status = SubmoduleStatus.modified;
          }
          
          final isInitialized = !statusSet.contains(GitSubmoduleStatus.workdirUninitialized);

          submodules.add(SubmoduleEntity(
            name: sub.name,
            path: sub.path,
            url: sub.url,
            sha: headSha,
            status: status,
            isInitialized: isInitialized,
          ));
        } catch (_) {}
      }
    } catch (_) {}
    r.free();
    return submodules;
  }

  @override
  Future<void> initSubmodules(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final paths = Submodule.list(r);
    for (final p in paths) {
      try {
        Submodule.init(repo: r, name: p);
      } catch (_) {}
    }
    r.free();
  }

  @override
  Future<void> updateSubmodules(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final paths = Submodule.list(r);
    for (final p in paths) {
      try {
        Submodule.update(repo: r, name: p, init: true);
      } catch (_) {}
    }
    r.free();
  }

  @override
  Future<void> syncSubmodules(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final paths = Submodule.list(r);
    for (final p in paths) {
      try {
        final sub = Submodule.lookup(repo: r, name: p);
        sub.sync();
      } catch (_) {}
    }
    r.free();
  }

  @override
  Future<bool> isBareRepository(GitRepo repo) async {
    final r = Repository.open(repo.path);
    final isBare = r.isBare;
    r.free();
    return isBare;
  }

  @override
  Future<List<String>> getTreeFiles(GitRepo repo, {String? ref}) async {
    final r = Repository.open(repo.path);
    final list = <String>[];
    Commit? commit;
    Tree? tree;
    Reference? headRef;
    final subTrees = <Tree>[];
    try {
      final Oid commitOid;
      if (ref != null) {
        commitOid = Oid.fromSHA(r, ref);
      } else {
        // Keep headRef alive until after Commit.lookup — Oid points into the ref.
        headRef = r.head;
        commitOid = headRef.target;
      }
      commit = Commit.lookup(repo: r, oid: commitOid);
      tree = commit.tree;

      void traverse(Tree t, String currentPath) {
        for (var i = 0; i < t.length; i++) {
          final entry = t[i];
          final entryPath = currentPath.isEmpty ? entry.name : '$currentPath/${entry.name}';
          if (entry.type == GitObject.tree) {
            final subTree = entry.toObject(r) as Tree;
            subTrees.add(subTree);
            traverse(subTree, entryPath);
          } else if (entry.type == GitObject.blob) {
            list.add(entryPath);
          }
        }
      }

      traverse(tree, '');
    } catch (_) {
      // Empty / unborn HEAD → no files.
    } finally {
      for (final st in subTrees) {
        try {
          st.free();
        } catch (_) {}
      }
      tree?.free();
      commit?.free();
      headRef?.free();
      r.free();
    }
    return list;
  }

  /// Maximum size (bytes) of a file that can be loaded into the in-app editor.
  /// Larger / binary files are rejected so Android bare-repo edits stay safe.
  static const int maxEditableFileBytes = 1 * 1024 * 1024;

  @override
  Future<String> getFileContentAtRef(GitRepo repo, String path, {String? ref}) async {
    final r = Repository.open(repo.path);
    Commit? commit;
    Tree? tree;
    Blob? blob;
    Reference? headRef;
    final openTrees = <Tree>[];
    try {
      final Oid commitOid;
      if (ref != null) {
        commitOid = Oid.fromSHA(r, ref);
      } else {
        // Keep headRef alive until after Commit.lookup — Oid points into the ref.
        headRef = r.head;
        commitOid = headRef.target;
      }
      commit = Commit.lookup(repo: r, oid: commitOid);
      tree = commit.tree;

      final entry = _findEntryByPath(r, tree, path, openTrees);
      if (entry == null || entry.type != GitObject.blob) {
        throw GitException(
          'cat-file $path',
          1,
          'File not found at revision: $path',
        );
      }
      blob = entry.toObject(r) as Blob;
      if (blob.isBinary) {
        throw GitException(
          'cat-file $path',
          1,
          'Binary files cannot be edited in Furcate.',
        );
      }
      if (blob.size > maxEditableFileBytes) {
        throw GitException(
          'cat-file $path',
          1,
          'File is too large to edit (${blob.size} bytes; limit $maxEditableFileBytes).',
        );
      }
      return blob.content;
    } finally {
      blob?.free();
      for (final t in openTrees) {
        try {
          t.free();
        } catch (_) {}
      }
      tree?.free();
      commit?.free();
      headRef?.free();
      r.free();
    }
  }

  TreeEntry? _findEntryByPath(Repository repo, Tree rootTree, String path, List<Tree> openTrees) {
    final parts = path.split('/');
    Tree currentTree = rootTree;
    
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      TreeEntry? found;
      for (var j = 0; j < currentTree.length; j++) {
        final e = currentTree[j];
        if (e.name == part) {
          found = e;
          break;
        }
      }
      if (found == null) return null;
      
      if (i == parts.length - 1) {
        return found;
      } else {
        if (found.type == GitObject.tree) {
          final subTree = found.toObject(repo) as Tree;
          openTrees.add(subTree);
          currentTree = subTree;
        } else {
          return null;
        }
      }
    }
    return null;
  }

  @override
  Future<void> writeAndCommitFile(
    GitRepo repo,
    String path,
    String content,
    String commitMessage,
  ) async {
    final r = Repository.open(repo.path);
    Commit? headCommit;
    Tree? rootTree;
    Tree? newTree;
    final openTrees = <Tree>[];
    try {
      final newBlobOid = Blob.create(repo: r, content: content);
      
      if (!r.isEmpty) {
        // Lookup while HEAD ref is still alive (Oid points into the ref).
        final parent = _withHeadOid(
          r,
          (oid) => Commit.lookup(repo: r, oid: oid),
        );
        headCommit = parent;
        rootTree = parent.tree;
      }
      
      final pathParts = path.split('/');
      final newTreeOid = _updateTreeRecursively(
        repo: r,
        currentTree: rootTree,
        pathParts: pathParts,
        newBlobOid: newBlobOid,
        openTrees: openTrees,
      );
      
      newTree = Tree.lookup(repo: r, oid: newTreeOid);
      
      Signature? signature;
      try {
        signature = Signature.create(
          name: 'Furcate User',
          email: 'user@furcate.app',
          time: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        
        Commit.create(
          repo: r,
          updateRef: 'HEAD',
          message: commitMessage,
          author: signature,
          committer: signature,
          tree: newTree,
          parents: headCommit != null ? [headCommit] : [],
        );
      } finally {
        signature?.free();
      }
    } catch (_) {
      rethrow;
    } finally {
      newTree?.free();
      for (final t in openTrees) {
        try {
          t.free();
        } catch (_) {}
      }
      headCommit?.free();
      rootTree?.free();
      r.free();
    }
  }

  Oid _updateTreeRecursively({
    required Repository repo,
    required Tree? currentTree,
    required List<String> pathParts,
    required Oid newBlobOid,
    required List<Tree> openTrees,
  }) {
    final builder = TreeBuilder(repo: repo, tree: currentTree);
    final currentPart = pathParts.first;
    
    if (pathParts.length == 1) {
      builder.add(
        filename: currentPart,
        oid: newBlobOid,
        filemode: GitFilemode.blob,
      );
      final newTreeOid = builder.write();
      builder.free();
      return newTreeOid;
    } else {
      Tree? subTree;
      try {
        if (currentTree != null) {
          for (var i = 0; i < currentTree.length; i++) {
            final e = currentTree[i];
            if (e.name == currentPart) {
              if (e.type == GitObject.tree) {
                subTree = e.toObject(repo) as Tree;
                openTrees.add(subTree);
              }
              break;
            }
          }
        }
      } catch (_) {}
      
      final newSubTreeOid = _updateTreeRecursively(
        repo: repo,
        currentTree: subTree,
        pathParts: pathParts.sublist(1),
        newBlobOid: newBlobOid,
        openTrees: openTrees,
      );
      
      builder.add(
        filename: currentPart,
        oid: newSubTreeOid,
        filemode: GitFilemode.tree,
      );
      final newTreeOid = builder.write();
      builder.free();
      return newTreeOid;
    }
  }
}

/// Internal helper for collecting remote fetch/push URLs.
class _RemoteUrls {
  String? fetchUrl;
  String? pushUrl;
}
