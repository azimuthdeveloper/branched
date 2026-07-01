import 'dart:async';
import 'dart:math';
import 'git_models.dart';
import 'git_service.dart';

class MockGitService implements GitService {
  final Map<String, _MockRepoState> _repoStates = {};

  _MockRepoState _getOrCreateState(GitRepo repo) {
    return _repoStates.putIfAbsent(repo.path, () => _MockRepoState(repo.path));
  }

  @override
  Future<GitRepo> openRepository(String path) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final name = path.split('/').lastWhere((e) => e.isNotEmpty, orElse: () => 'repository');
    final repo = GitRepo(path: path, name: name);
    _getOrCreateState(repo);
    return repo;
  }

  @override
  Future<GitRepo> cloneRepository(String url, String path, {String? username, String? password, void Function(double)? onProgress}) async {
    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (onProgress != null) {
        onProgress(i / steps);
      }
    }
    final name = path.split('/').lastWhere((e) => e.isNotEmpty, orElse: () => 'cloned-repo');
    final repo = GitRepo(path: path, name: name);
    final state = _getOrCreateState(repo);
    // Add some remote commits to simulate clone
    state.remotes.add(const RemoteEntity(name: 'origin', url: 'https://github.com/mock/repo.git'));
    return repo;
  }

  @override
  Future<GitRepo> initRepository(String path, {bool bare = false}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final name = path.split('/').lastWhere((e) => e.isNotEmpty, orElse: () => 'new-repo');
    final repo = GitRepo(path: path, name: name);
    final state = _getOrCreateState(repo);
    state.commits.clear();
    state.branches.clear();
    state.branches.add(const BranchEntity(name: 'main', shortName: 'main', tipSha: '', isHead: true, isRemote: false));
    return repo;
  }

  @override
  Future<bool> isGitRepository(String path) async {
    return true;
  }

  @override
  void disposeRepository(GitRepo repo) {
    // No-op for mock
  }

  @override
  Future<List<BranchEntity>> getBranches(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    return state.branches.where((b) => !b.isRemote).toList();
  }

  @override
  Future<List<BranchEntity>> getRemoteBranches(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    return state.branches.where((b) => b.isRemote).toList();
  }

  @override
  Future<BranchEntity> createBranch(GitRepo repo, String name, {String? startPoint}) async {
    final state = _getOrCreateState(repo);
    final current = state.getCurrentBranch();
    final newBranch = BranchEntity(
      name: name,
      shortName: name.split('/').last,
      tipSha: current.tipSha,
      isHead: false,
      isRemote: false,
    );
    state.branches.add(newBranch);
    return newBranch;
  }

  @override
  Future<void> deleteBranch(GitRepo repo, String name, {bool force = false}) async {
    final state = _getOrCreateState(repo);
    state.branches.removeWhere((b) => b.name == name);
  }

  @override
  Future<void> renameBranch(GitRepo repo, String oldName, String newName) async {
    final state = _getOrCreateState(repo);
    final index = state.branches.indexWhere((b) => b.name == oldName);
    if (index != -1) {
      final old = state.branches[index];
      state.branches[index] = BranchEntity(
        name: newName,
        shortName: newName.split('/').last,
        tipSha: old.tipSha,
        isHead: old.isHead,
        isRemote: old.isRemote,
      );
    }
  }

  @override
  Future<void> checkoutBranch(GitRepo repo, String name) async {
    final state = _getOrCreateState(repo);
    for (var i = 0; i < state.branches.length; i++) {
      final b = state.branches[i];
      state.branches[i] = BranchEntity(
        name: b.name,
        shortName: b.shortName,
        tipSha: b.tipSha,
        isHead: b.name == name,
        isRemote: b.isRemote,
        trackingBranch: b.trackingBranch,
        ahead: b.ahead,
        behind: b.behind,
      );
    }
  }

  @override
  Future<BranchEntity> getCurrentBranch(GitRepo repo) async {
    return _getOrCreateState(repo).getCurrentBranch();
  }

  @override
  Future<List<CommitEntity>> getCommitHistory(GitRepo repo, {String? branch, int limit = 100, int offset = 0}) async {
    final state = _getOrCreateState(repo);
    return state.commits;
  }

  @override
  Future<CommitEntity> getCommit(GitRepo repo, String sha) async {
    final state = _getOrCreateState(repo);
    return state.commits.firstWhere((c) => c.sha == sha);
  }

  @override
  Future<CommitEntity> createCommit(GitRepo repo, String message, {AuthorEntity? author, bool amend = false}) async {
    final state = _getOrCreateState(repo);
    final curBranch = state.getCurrentBranch();
    final authorEntity = author ?? const AuthorEntity(name: 'Developer', email: 'dev@furcate.com');
    final sha = _randomSha();

    final newCommit = CommitEntity(
      sha: sha,
      shortSha: sha.substring(0, 7),
      message: message,
      summary: message.split('\n').first,
      author: authorEntity,
      committer: authorEntity,
      dateTime: DateTime.now(),
      parentShas: curBranch.tipSha.isNotEmpty ? [curBranch.tipSha] : [],
      isHead: true,
      isMergeCommit: false,
      refs: [RefEntity(name: curBranch.name, type: 'local')],
    );

    // Update old HEAD commit
    for (var i = 0; i < state.commits.length; i++) {
      final c = state.commits[i];
      if (c.sha == curBranch.tipSha) {
        state.commits[i] = CommitEntity(
          sha: c.sha,
          shortSha: c.shortSha,
          message: c.message,
          summary: c.summary,
          author: c.author,
          committer: c.committer,
          dateTime: c.dateTime,
          parentShas: c.parentShas,
          isHead: false,
          isMergeCommit: c.isMergeCommit,
          refs: c.refs.where((r) => r.name != curBranch.name).toList(),
        );
      }
    }

    state.commits.insert(0, newCommit);

    // Update branch tip
    final bIndex = state.branches.indexWhere((b) => b.name == curBranch.name);
    if (bIndex != -1) {
      state.branches[bIndex] = BranchEntity(
        name: curBranch.name,
        shortName: curBranch.shortName,
        tipSha: sha,
        isHead: true,
        isRemote: false,
      );
    }

    // Clear staged files
    state.stagedFiles.clear();

    return newCommit;
  }

  @override
  Future<WorkingCopyStatus> getStatus(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    return WorkingCopyStatus(
      unstagedFiles: state.unstagedFiles,
      stagedFiles: state.stagedFiles,
      conflictedFiles: state.conflictedFiles,
    );
  }

  @override
  Future<void> stageFile(GitRepo repo, String path) async {
    final state = _getOrCreateState(repo);
    final fileIndex = state.unstagedFiles.indexWhere((f) => f.path == path);
    if (fileIndex != -1) {
      final file = state.unstagedFiles.removeAt(fileIndex);
      state.stagedFiles.add(FileStatusEntity(path: file.path, status: file.status, isNew: file.isNew, isRenamed: file.isRenamed, oldPath: file.oldPath));
    }
  }

  @override
  Future<void> unstageFile(GitRepo repo, String path) async {
    final state = _getOrCreateState(repo);
    final fileIndex = state.stagedFiles.indexWhere((f) => f.path == path);
    if (fileIndex != -1) {
      final file = state.stagedFiles.removeAt(fileIndex);
      state.unstagedFiles.add(FileStatusEntity(path: file.path, status: file.status, isNew: file.isNew, isRenamed: file.isRenamed, oldPath: file.oldPath));
    }
  }

  @override
  Future<void> stageAll(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    state.stagedFiles.addAll(state.unstagedFiles);
    state.unstagedFiles.clear();
  }

  @override
  Future<void> unstageAll(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    state.unstagedFiles.addAll(state.stagedFiles);
    state.stagedFiles.clear();
  }

  @override
  Future<void> discardFile(GitRepo repo, String path) async {
    final state = _getOrCreateState(repo);
    state.unstagedFiles.removeWhere((f) => f.path == path);
  }

  @override
  Future<void> discardAll(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    state.unstagedFiles.clear();
  }

  @override
  Future<FileDiffEntity> getWorkingDiff(GitRepo repo, String path, {bool staged = false}) async {
    return FileDiffEntity(
      path: path,
      status: FileChangeStatus.modified,
      isBinary: false,
      addedLines: 3,
      deletedLines: 1,
      hunks: [
        DiffHunkEntity(
          oldStart: 10,
          oldLines: 3,
          newStart: 10,
          newLines: 5,
          header: '@@ -10,3 +10,5 @@ class AppController {',
          lines: [
            const DiffLineEntity(content: ' class AppController {', origin: DiffLineOrigin.context, oldLineNumber: 10, newLineNumber: 10),
            const DiffLineEntity(content: '   final GitService gitService;', origin: DiffLineOrigin.context, oldLineNumber: 11, newLineNumber: 11),
            const DiffLineEntity(content: '-  void initialize() {', origin: DiffLineOrigin.deletion, oldLineNumber: 12),
            const DiffLineEntity(content: '+  Future<void> initializeAsync() async {', origin: DiffLineOrigin.addition, newLineNumber: 12),
            const DiffLineEntity(content: '+    await gitService.openRepository(path);', origin: DiffLineOrigin.addition, newLineNumber: 13),
            const DiffLineEntity(content: '+    _updateState();', origin: DiffLineOrigin.addition, newLineNumber: 14),
            const DiffLineEntity(content: '   }', origin: DiffLineOrigin.context, oldLineNumber: 13, newLineNumber: 15),
          ],
        ),
      ],
    );
  }

  @override
  Future<List<FileDiffEntity>> getCommitDiff(GitRepo repo, String sha) async {
    return [
      const FileDiffEntity(
        path: 'lib/main.dart',
        status: FileChangeStatus.modified,
        isBinary: false,
        addedLines: 2,
        deletedLines: 0,
        hunks: [
          DiffHunkEntity(
            oldStart: 1,
            oldLines: 2,
            newStart: 1,
            newLines: 4,
            header: '@@ -1,2 +1,4 @@',
            lines: [
              DiffLineEntity(content: ' import \'package:flutter/material.dart\';', origin: DiffLineOrigin.context, oldLineNumber: 1, newLineNumber: 1),
              DiffLineEntity(content: '+import \'package:flutter_bloc/flutter_bloc.dart\';', origin: DiffLineOrigin.addition, newLineNumber: 2),
              DiffLineEntity(content: '+import \'git_engine/git_service.dart\';', origin: DiffLineOrigin.addition, newLineNumber: 3),
              DiffLineEntity(content: ' void main() => runApp(const MyApp());', origin: DiffLineOrigin.context, oldLineNumber: 2, newLineNumber: 4),
            ],
          ),
        ],
      )
    ];
  }

  @override
  Future<FileDiffEntity> getFileDiffForCommit(GitRepo repo, String sha, String path) async {
    final diffs = await getCommitDiff(repo, sha);
    return diffs.firstWhere((d) => d.path == path, orElse: () => FileDiffEntity(path: path, status: FileChangeStatus.modified, hunks: const [], isBinary: false, addedLines: 0, deletedLines: 0));
  }

  @override
  Future<void> merge(GitRepo repo, String sourceBranch) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final state = _getOrCreateState(repo);
    final curBranch = state.getCurrentBranch();

    // Create a mock merge commit
    final sha = _randomSha();
    final newCommit = CommitEntity(
      sha: sha,
      shortSha: sha.substring(0, 7),
      message: 'Merge branch \'$sourceBranch\' into ${curBranch.name}',
      summary: 'Merge branch \'$sourceBranch\' into ${curBranch.name}',
      author: const AuthorEntity(name: 'Developer', email: 'dev@furcate.com'),
      committer: const AuthorEntity(name: 'Developer', email: 'dev@furcate.com'),
      dateTime: DateTime.now(),
      parentShas: [curBranch.tipSha, _findBranchTip(state, sourceBranch)],
      isHead: true,
      isMergeCommit: true,
      refs: [RefEntity(name: curBranch.name, type: 'local')],
    );

    // Update old HEAD commit
    for (var i = 0; i < state.commits.length; i++) {
      final c = state.commits[i];
      if (c.sha == curBranch.tipSha) {
        state.commits[i] = CommitEntity(
          sha: c.sha,
          shortSha: c.shortSha,
          message: c.message,
          summary: c.summary,
          author: c.author,
          committer: c.committer,
          dateTime: c.dateTime,
          parentShas: c.parentShas,
          isHead: false,
          isMergeCommit: c.isMergeCommit,
          refs: c.refs.where((r) => r.name != curBranch.name).toList(),
        );
      }
    }

    state.commits.insert(0, newCommit);

    // Update branch tip
    final bIndex = state.branches.indexWhere((b) => b.name == curBranch.name);
    if (bIndex != -1) {
      state.branches[bIndex] = BranchEntity(
        name: curBranch.name,
        shortName: curBranch.shortName,
        tipSha: sha,
        isHead: true,
        isRemote: false,
      );
    }
  }

  @override
  Future<void> abortMerge(GitRepo repo) async {
    final state = _getOrCreateState(repo);
    state.conflictedFiles.clear();
  }

  @override
  Future<void> rebase(GitRepo repo, String branch) async {}

  @override
  Future<void> continueRebase(GitRepo repo) async {}

  @override
  Future<void> abortRebase(GitRepo repo) async {}

  @override
  Future<void> cherryPick(GitRepo repo, String sha) async {}

  @override
  Future<void> revertCommit(GitRepo repo, String sha) async {}

  @override
  Future<void> reset(GitRepo repo, String sha, {required String mode}) async {}

  @override
  Future<List<RemoteEntity>> getRemotes(GitRepo repo) async {
    return _getOrCreateState(repo).remotes;
  }

  @override
  Future<void> addRemote(GitRepo repo, String name, String url) async {
    final state = _getOrCreateState(repo);
    state.remotes.add(RemoteEntity(name: name, url: url));
  }

  @override
  Future<void> removeRemote(GitRepo repo, String name) async {
    final state = _getOrCreateState(repo);
    state.remotes.removeWhere((r) => r.name == name);
  }

  @override
  Future<void> fetch(GitRepo repo, {String? remote, void Function(double)? onProgress}) async {
    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (onProgress != null) onProgress(i / 5);
    }
  }

  @override
  Future<void> pull(GitRepo repo, {String? remote, void Function(double)? onProgress}) async {
    await fetch(repo, remote: remote, onProgress: onProgress);
    // Auto merge from tracking branch
    final state = _getOrCreateState(repo);
    final current = state.getCurrentBranch();
    if (current.trackingBranch != null) {
      await merge(repo, current.trackingBranch!);
    }
  }

  @override
  Future<void> push(GitRepo repo, {String? remote, String? branch, bool force = false, void Function(double)? onProgress}) async {
    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (onProgress != null) onProgress(i / 5);
    }
  }

  @override
  Future<List<TagEntity>> getTags(GitRepo repo) async {
    return _getOrCreateState(repo).tags;
  }

  @override
  Future<TagEntity> createTag(GitRepo repo, String name, {String? target, String? message}) async {
    final state = _getOrCreateState(repo);
    final targetSha = target ?? state.getCurrentBranch().tipSha;
    final tag = TagEntity(name: name, sha: targetSha, message: message, isAnnotated: message != null);
    state.tags.add(tag);
    return tag;
  }

  @override
  Future<void> deleteTag(GitRepo repo, String name) async {
    final state = _getOrCreateState(repo);
    state.tags.removeWhere((t) => t.name == name);
  }

  @override
  Future<List<StashEntity>> getStashes(GitRepo repo) async {
    return _getOrCreateState(repo).stashes;
  }

  @override
  Future<StashEntity> createStash(GitRepo repo, {String? message, bool includeUntracked = false}) async {
    final state = _getOrCreateState(repo);
    final sha = _randomSha();
    final newStash = StashEntity(
      index: 0,
      message: message ?? 'On ${state.getCurrentBranch().name}: Working changes',
      sha: sha,
      dateTime: DateTime.now(),
    );

    // Shift stashes
    for (var i = 0; i < state.stashes.length; i++) {
      final s = state.stashes[i];
      state.stashes[i] = StashEntity(index: s.index + 1, message: s.message, sha: s.sha, dateTime: s.dateTime);
    }

    state.stashes.insert(0, newStash);
    state.unstagedFiles.clear();
    state.stagedFiles.clear();

    return newStash;
  }

  @override
  Future<void> applyStash(GitRepo repo, int index) async {
    final state = _getOrCreateState(repo);
    if (index >= 0 && index < state.stashes.length) {
      state.unstagedFiles.add(const FileStatusEntity(path: 'lib/main.dart', status: FileChangeStatus.modified));
    }
  }

  @override
  Future<void> dropStash(GitRepo repo, int index) async {
    final state = _getOrCreateState(repo);
    if (index >= 0 && index < state.stashes.length) {
      state.stashes.removeAt(index);
      // Re-index
      for (var i = 0; i < state.stashes.length; i++) {
        final s = state.stashes[i];
        state.stashes[i] = StashEntity(index: i, message: s.message, sha: s.sha, dateTime: s.dateTime);
      }
    }
  }

  @override
  Future<void> popStash(GitRepo repo, int index) async {
    await applyStash(repo, index);
    await dropStash(repo, index);
  }

  @override
  Future<List<SubmoduleEntity>> getSubmodules(GitRepo repo) async => [
        const SubmoduleEntity(
          name: 'plugins/my_plugin',
          path: 'plugins/my_plugin',
          url: 'https://github.com/example/my_plugin.git',
          sha: 'abc123abc123abc123abc123abc123abc123abc1',
          status: SubmoduleStatus.clean,
          isInitialized: true,
        ),
      ];

  @override
  Future<void> initSubmodules(GitRepo repo) async {}

  @override
  Future<void> updateSubmodules(GitRepo repo) async {}

  @override
  Future<void> syncSubmodules(GitRepo repo) async {}

  String _randomSha() {
    final r = Random();
    const chars = '0123456789abcdef';
    return List.generate(40, (_) => chars[r.nextInt(16)]).join();
  }

  String _findBranchTip(_MockRepoState state, String branchName) {
    try {
      return state.branches.firstWhere((b) => b.name == branchName).tipSha;
    } catch (_) {
      return '';
    }
  }
}

class _MockRepoState {
  final String path;
  final List<BranchEntity> branches = [];
  final List<CommitEntity> commits = [];
  final List<FileStatusEntity> unstagedFiles = [];
  final List<FileStatusEntity> stagedFiles = [];
  final List<FileStatusEntity> conflictedFiles = [];
  final List<StashEntity> stashes = [];
  final List<RemoteEntity> remotes = [];
  final List<TagEntity> tags = [];

  _MockRepoState(this.path) {
    _initMockData();
  }

  BranchEntity getCurrentBranch() {
    return branches.firstWhere((b) => b.isHead, orElse: () => branches.first);
  }

  void _initMockData() {
    // 5 commits back in history
    final sha1 = 'e2e604f326305a417537b019b88d3e913a474c10';
    final sha2 = 'f5e612f326305a417537b019b88d3e913a474c11';
    final sha3 = 'a6b2c3d526305a417537b019b88d3e913a474c12';
    final sha4 = 'c586c0d526305a417537b019b88d3e913a474c13';
    final sha5 = '569cd6f526305a417537b019b88d3e913a474c14';

    branches.add(BranchEntity(name: 'main', shortName: 'main', tipSha: sha5, isHead: true, isRemote: false, trackingBranch: 'origin/main', ahead: 0, behind: 0));
    branches.add(BranchEntity(name: 'feature/auth', shortName: 'feature/auth', tipSha: sha4, isHead: false, isRemote: false));
    branches.add(BranchEntity(name: 'origin/main', shortName: 'main', tipSha: sha5, isHead: false, isRemote: true));

    commits.addAll([
      CommitEntity(
        sha: sha5,
        shortSha: sha5.substring(0, 7),
        message: 'Merge branch \'feature/auth\' into main',
        summary: 'Merge branch \'feature/auth\' into main',
        author: const AuthorEntity(name: 'Alice Johnson', email: 'alice@furcate.com'),
        committer: const AuthorEntity(name: 'Alice Johnson', email: 'alice@furcate.com'),
        dateTime: DateTime.now().subtract(const Duration(hours: 1)),
        parentShas: [sha3, sha4],
        isHead: true,
        isMergeCommit: true,
        refs: [const RefEntity(name: 'main', type: 'local'), const RefEntity(name: 'origin/main', type: 'remote')],
      ),
      CommitEntity(
        sha: sha4,
        shortSha: sha4.substring(0, 7),
        message: 'feat: add biometrics authentication option\n\nIntegrates local_auth to support faceID and touchID.',
        summary: 'feat: add biometrics authentication option',
        author: const AuthorEntity(name: 'Bob Smith', email: 'bob@furcate.com'),
        committer: const AuthorEntity(name: 'Bob Smith', email: 'bob@furcate.com'),
        dateTime: DateTime.now().subtract(const Duration(hours: 4)),
        parentShas: [sha2],
        isHead: false,
        isMergeCommit: false,
        refs: [const RefEntity(name: 'feature/auth', type: 'local')],
      ),
      CommitEntity(
        sha: sha3,
        shortSha: sha3.substring(0, 7),
        message: 'chore: update dependency packages in pubspec.yaml',
        summary: 'chore: update dependency packages in pubspec.yaml',
        author: const AuthorEntity(name: 'Alice Johnson', email: 'alice@furcate.com'),
        committer: const AuthorEntity(name: 'Alice Johnson', email: 'alice@furcate.com'),
        dateTime: DateTime.now().subtract(const Duration(hours: 8)),
        parentShas: [sha2],
        isHead: false,
        isMergeCommit: false,
        refs: const [],
      ),
      CommitEntity(
        sha: sha2,
        shortSha: sha2.substring(0, 7),
        message: 'fix: handle session timeout gracefully',
        summary: 'fix: handle session timeout gracefully',
        author: const AuthorEntity(name: 'Bob Smith', email: 'bob@furcate.com'),
        committer: const AuthorEntity(name: 'Bob Smith', email: 'bob@furcate.com'),
        dateTime: DateTime.now().subtract(const Duration(days: 1)),
        parentShas: [sha1],
        isHead: false,
        isMergeCommit: false,
        refs: const [],
      ),
      CommitEntity(
        sha: sha1,
        shortSha: sha1.substring(0, 7),
        message: 'Initial commit',
        summary: 'Initial commit',
        author: const AuthorEntity(name: 'Alice Johnson', email: 'alice@furcate.com'),
        committer: const AuthorEntity(name: 'Alice Johnson', email: 'alice@furcate.com'),
        dateTime: DateTime.now().subtract(const Duration(days: 5)),
        parentShas: const [],
        isHead: false,
        isMergeCommit: false,
        refs: const [],
      ),
    ]);

    unstagedFiles.addAll([
      const FileStatusEntity(path: 'lib/core/theme.dart', status: FileChangeStatus.modified),
      const FileStatusEntity(path: 'lib/features/dashboard.dart', status: FileChangeStatus.added, isNew: true),
      const FileStatusEntity(path: 'assets/logo.png', status: FileChangeStatus.untracked, isNew: true),
    ]);

    stagedFiles.addAll([
      const FileStatusEntity(path: 'pubspec.yaml', status: FileChangeStatus.modified),
    ]);

    remotes.add(const RemoteEntity(name: 'origin', url: 'https://github.com/furcate/branched.git'));

    tags.add(const TagEntity(name: 'v1.0.0', sha: 'e2e604f326305a417537b019b88d3e913a474c10', isAnnotated: false));

    stashes.add(StashEntity(index: 0, message: 'On main: stash prior to merge', sha: 'ab88d3e913a474c10ab88d3e913a474c10', dateTime: DateTime.now().subtract(const Duration(days: 2))));
  }
}
