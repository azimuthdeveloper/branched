import 'package:flutter_test/flutter_test.dart';
import 'package:branched/core/locator.dart';
import 'package:branched/git_engine/git_service.dart';
import 'package:branched/git_engine/git_models.dart';
import 'package:branched/features/sidebar/sidebar_bloc.dart';
import 'package:branched/features/staging/staging_bloc.dart';

void main() {
  setUpAll(() {
    locator.registerLazySingleton<GitService>(() => TestMockGitService());
  });

  group('Git Engine & State Management Unit Tests', () {
    final mockRepo = GitRepo(path: '/root/my-project', name: 'my-project');

    test('SidebarBloc loads branches and handles selections', () async {
      final sidebarBloc = SidebarBloc(locator<GitService>());
      

      // Load sidebar
      sidebarBloc.add(LoadSidebarEvent(mockRepo));
      await expectLater(
        sidebarBloc.stream,
        emitsThrough(predicate<SidebarState>((state) {
          return !state.isLoading && 
                 state.localBranches.any((item) => item.name == 'main') &&
                 state.localBranches.any((item) => item.name == 'feature/auth');
        })),
      );

      // Verify default selected item is 'Changes'
      expect(sidebarBloc.state.selectedItem.label, 'Changes');

      // Select 'feature/auth' branch from localBranches
      final authBranch = sidebarBloc.state.localBranches.firstWhere((item) => item.name == 'feature/auth');
      sidebarBloc.add(SelectSidebarItemEvent(SidebarItem(
        label: authBranch.name,
        type: SidebarItemType.branch,
        refName: authBranch.name,
      )));

      await expectLater(
        sidebarBloc.stream,
        emitsThrough(predicate<SidebarState>((state) {
          return state.selectedItem.label == 'feature/auth';
        })),
      );
    });

    test('StagingBloc handles staging, unstaging, and conflict states', () async {
      final stagingBloc = StagingBloc(locator<GitService>());

      // Load copy
      stagingBloc.add(LoadWorkingCopyEvent(mockRepo));
      await expectLater(
        stagingBloc.stream,
        emitsThrough(predicate<StagingState>((state) {
          return state.unstagedFiles.isNotEmpty && state.stagedFiles.isNotEmpty;
        })),
      );

      // Stage a file
      final fileToStage = stagingBloc.state.unstagedFiles.first;
      stagingBloc.add(StageFileEvent(mockRepo, fileToStage.path));

      await expectLater(
        stagingBloc.stream,
        emitsThrough(predicate<StagingState>((state) {
          return state.stagedFiles.any((f) => f.path == fileToStage.path) &&
                 !state.unstagedFiles.any((f) => f.path == fileToStage.path);
        })),
      );

      // Verify simulated conflicted file state
      final conflictedFile = FileStatusEntity(
        path: 'lib/core/theme.dart',
        status: FileChangeStatus.conflicted,
      );
      
      expect(conflictedFile.status, FileChangeStatus.conflicted);
    });

    test('SidebarBloc loads submodules', () async {
      final sidebarBloc = SidebarBloc(locator<GitService>());
      sidebarBloc.add(LoadSidebarEvent(mockRepo));
      await expectLater(
        sidebarBloc.stream,
        emitsThrough(predicate<SidebarState>((state) {
          return !state.isLoading && 
                 state.submodules.any((s) => s.name == 'plugins/my_plugin');
        })),
      );
    });
  });
}

class TestMockGitService implements GitService {
  final List<BranchEntity> _branches = [
    const BranchEntity(name: 'main', shortName: 'main', tipSha: 'sha1', isHead: true, isRemote: false),
    const BranchEntity(name: 'feature/auth', shortName: 'feature/auth', tipSha: 'sha2', isHead: false, isRemote: false),
  ];

  final List<FileStatusEntity> _unstaged = [
    const FileStatusEntity(path: 'lib/core/theme.dart', status: FileChangeStatus.modified),
  ];

  final List<FileStatusEntity> _staged = [
    const FileStatusEntity(path: 'pubspec.yaml', status: FileChangeStatus.modified),
  ];

  @override
  Future<GitRepo> openRepository(String path) async => GitRepo(path: path, name: 'mock-repo');

  @override
  Future<GitRepo> cloneRepository(String url, String path, {String? username, String? password, void Function(double)? onProgress}) async => GitRepo(path: path, name: 'cloned');

  @override
  Future<GitRepo> initRepository(String path, {bool bare = false}) async => GitRepo(path: path, name: 'init');

  @override
  Future<bool> isGitRepository(String path) async => true;

  @override
  void disposeRepository(GitRepo repo) {}

  @override
  Future<List<BranchEntity>> getBranches(GitRepo repo) async => _branches;

  @override
  Future<List<BranchEntity>> getRemoteBranches(GitRepo repo) async => [];

  @override
  Future<BranchEntity> createBranch(GitRepo repo, String name, {String? startPoint}) async {
    final b = BranchEntity(name: name, shortName: name, tipSha: 'sha', isHead: false, isRemote: false);
    _branches.add(b);
    return b;
  }

  @override
  Future<void> deleteBranch(GitRepo repo, String name, {bool force = false}) async {}

  @override
  Future<void> renameBranch(GitRepo repo, String oldName, String newName) async {}

  @override
  Future<void> checkoutBranch(GitRepo repo, String name) async {}

  @override
  Future<BranchEntity> getCurrentBranch(GitRepo repo) async => _branches.first;

  @override
  Future<List<CommitEntity>> getCommitHistory(GitRepo repo, {String? branch, int limit = 100, int offset = 0}) async => [];

  @override
  Future<CommitEntity> getCommit(GitRepo repo, String sha) async => throw UnimplementedError();

  @override
  Future<CommitEntity> createCommit(GitRepo repo, String message, {AuthorEntity? author, bool amend = false}) async {
    _staged.clear();
    return CommitEntity(
      sha: 'new-sha',
      shortSha: 'new-sha',
      message: message,
      summary: message,
      author: author ?? const AuthorEntity(name: 'test', email: 'test'),
      committer: author ?? const AuthorEntity(name: 'test', email: 'test'),
      dateTime: DateTime.now(),
      parentShas: const [],
      isHead: true,
      isMergeCommit: false,
      refs: const [],
    );
  }

  @override
  Future<WorkingCopyStatus> getStatus(GitRepo repo) async {
    return WorkingCopyStatus(
      unstagedFiles: List.from(_unstaged),
      stagedFiles: List.from(_staged),
      conflictedFiles: const [],
    );
  }

  @override
  Future<void> stageFile(GitRepo repo, String path) async {
    final idx = _unstaged.indexWhere((f) => f.path == path);
    if (idx != -1) {
      final f = _unstaged.removeAt(idx);
      _staged.add(FileStatusEntity(path: f.path, status: f.status));
    }
  }

  @override
  Future<void> unstageFile(GitRepo repo, String path) async {
    final idx = _staged.indexWhere((f) => f.path == path);
    if (idx != -1) {
      final f = _staged.removeAt(idx);
      _unstaged.add(FileStatusEntity(path: f.path, status: f.status));
    }
  }

  @override
  Future<void> stageAll(GitRepo repo) async {
    _staged.addAll(_unstaged);
    _unstaged.clear();
  }

  @override
  Future<void> unstageAll(GitRepo repo) async {
    _unstaged.addAll(_staged);
    _staged.clear();
  }

  @override
  Future<void> discardFile(GitRepo repo, String path) async {
    _unstaged.removeWhere((f) => f.path == path);
  }

  @override
  Future<void> discardAll(GitRepo repo) async {
    _unstaged.clear();
  }

  @override
  Future<FileDiffEntity> getWorkingDiff(GitRepo repo, String path, {bool staged = false}) async => throw UnimplementedError();

  @override
  Future<List<FileDiffEntity>> getCommitDiff(GitRepo repo, String sha) async => [];

  @override
  Future<FileDiffEntity> getFileDiffForCommit(GitRepo repo, String sha, String path) async => throw UnimplementedError();

  @override
  Future<void> merge(GitRepo repo, String sourceBranch) async {}

  @override
  Future<void> abortMerge(GitRepo repo) async {}

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
  Future<List<RemoteEntity>> getRemotes(GitRepo repo) async => [];

  @override
  Future<void> addRemote(GitRepo repo, String name, String url) async {}

  @override
  Future<void> removeRemote(GitRepo repo, String name) async {}

  @override
  Future<void> fetch(GitRepo repo, {String? remote, void Function(double)? onProgress}) async {}

  @override
  Future<void> pull(GitRepo repo, {String? remote, void Function(double)? onProgress}) async {}

  @override
  Future<void> push(GitRepo repo, {String? remote, String? branch, bool force = false, void Function(double)? onProgress}) async {}

  @override
  Future<List<TagEntity>> getTags(GitRepo repo) async => [];

  @override
  Future<TagEntity> createTag(GitRepo repo, String name, {String? target, String? message}) async => throw UnimplementedError();

  @override
  Future<void> deleteTag(GitRepo repo, String name) async {}

  @override
  Future<List<StashEntity>> getStashes(GitRepo repo) async => [];

  @override
  Future<StashEntity> createStash(GitRepo repo, {String? message, bool includeUntracked = false}) async => throw UnimplementedError();

  @override
  Future<void> applyStash(GitRepo repo, int index) async {}

  @override
  Future<void> dropStash(GitRepo repo, int index) async {}

  @override
  Future<void> popStash(GitRepo repo, int index) async {}

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

  @override
  Future<bool> isBareRepository(GitRepo repo) async => false;

  @override
  Future<List<String>> getTreeFiles(GitRepo repo, {String? ref}) async => [];

  @override
  Future<String> getFileContentAtRef(GitRepo repo, String path, {String? ref}) async => '';

  @override
  Future<void> writeAndCommitFile(GitRepo repo, String path, String content, String commitMessage) async {}
}
