import 'dart:async';
import 'git_models.dart';

class GitRepo {
  final String path;
  final String name;

  GitRepo({required this.path, required this.name});
}

abstract class GitService {
  // Repository Operations
  Future<GitRepo> openRepository(String path);
  Future<GitRepo> cloneRepository(String url, String path, {String? username, String? password, void Function(double)? onProgress});
  Future<GitRepo> initRepository(String path, {bool bare = false});
  Future<bool> isGitRepository(String path);
  void disposeRepository(GitRepo repo);

  // Branch Operations
  Future<List<BranchEntity>> getBranches(GitRepo repo);
  Future<List<BranchEntity>> getRemoteBranches(GitRepo repo);
  Future<BranchEntity> createBranch(GitRepo repo, String name, {String? startPoint});
  Future<void> deleteBranch(GitRepo repo, String name, {bool force = false});
  Future<void> renameBranch(GitRepo repo, String oldName, String newName);
  Future<void> checkoutBranch(GitRepo repo, String name);
  Future<BranchEntity> getCurrentBranch(GitRepo repo);

  // Commit Operations
  Future<List<CommitEntity>> getCommitHistory(GitRepo repo, {String? branch, int limit = 100, int offset = 0});
  Future<CommitEntity> getCommit(GitRepo repo, String sha);
  Future<CommitEntity> createCommit(GitRepo repo, String message, {AuthorEntity? author, bool amend = false});

  // Staging / Working Copy
  Future<WorkingCopyStatus> getStatus(GitRepo repo);
  Future<void> stageFile(GitRepo repo, String path);
  Future<void> unstageFile(GitRepo repo, String path);
  Future<void> stageAll(GitRepo repo);
  Future<void> unstageAll(GitRepo repo);
  Future<void> discardFile(GitRepo repo, String path);
  Future<void> discardAll(GitRepo repo);

  // Diff
  Future<FileDiffEntity> getWorkingDiff(GitRepo repo, String path, {bool staged = false});
  Future<List<FileDiffEntity>> getCommitDiff(GitRepo repo, String sha);
  Future<FileDiffEntity> getFileDiffForCommit(GitRepo repo, String sha, String path);

  // Merge / Rebase
  Future<void> merge(GitRepo repo, String sourceBranch);
  Future<void> abortMerge(GitRepo repo);

  // Remotes
  Future<List<RemoteEntity>> getRemotes(GitRepo repo);
  Future<void> addRemote(GitRepo repo, String name, String url);
  Future<void> removeRemote(GitRepo repo, String name);
  Future<void> fetch(GitRepo repo, {String? remote, void Function(double)? onProgress});
  Future<void> pull(GitRepo repo, {String? remote, void Function(double)? onProgress});
  Future<void> push(GitRepo repo, {String? remote, String? branch, bool force = false, void Function(double)? onProgress});

  // Tags
  Future<List<TagEntity>> getTags(GitRepo repo);
  Future<TagEntity> createTag(GitRepo repo, String name, {String? target, String? message});
  Future<void> deleteTag(GitRepo repo, String name);

  // Stashes
  Future<List<StashEntity>> getStashes(GitRepo repo);
  Future<StashEntity> createStash(GitRepo repo, {String? message, bool includeUntracked = false});
  Future<void> applyStash(GitRepo repo, int index);
  Future<void> dropStash(GitRepo repo, int index);
  Future<void> popStash(GitRepo repo, int index);
}
