import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Repository Operations
  // ---------------------------------------------------------------------------

  @override
  Future<GitRepo> openRepository(String path) async {
    final gitDir = Directory('$path/.git');
    if (!await gitDir.exists()) {
      // It could be a bare repo; try rev-parse as fallback.
      final result = await _run(
        ['rev-parse', '--git-dir'],
        workingDirectory: path,
        allowFailure: true,
      );
      if (result.exitCode != 0) {
        throw GitException('openRepository', 1, 'Not a git repository: $path');
      }
    }
    final name = path
        .split(Platform.pathSeparator)
        .lastWhere((e) => e.isNotEmpty, orElse: () => 'repository');
    return GitRepo(path: path, name: name);
  }

  @override
  Future<bool> isGitRepository(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return false;
    final result = await _run(
      ['rev-parse', '--git-dir'],
      workingDirectory: path,
      allowFailure: true,
    );
    return result.exitCode == 0;
  }

  @override
  Future<GitRepo> cloneRepository(
    String url,
    String path, {
    String? username,
    String? password,
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.0);

    // Build the effective URL with inline credentials when provided.
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

    final name = path
        .split(Platform.pathSeparator)
        .lastWhere((e) => e.isNotEmpty, orElse: () => 'cloned-repo');
    return GitRepo(path: path, name: name);
  }

  @override
  Future<GitRepo> initRepository(String path, {bool bare = false}) async {
    await Directory(path).create(recursive: true);
    final args = ['init'];
    if (bare) args.add('--bare');
    await _run(args, workingDirectory: path);
    final name = path
        .split(Platform.pathSeparator)
        .lastWhere((e) => e.isNotEmpty, orElse: () => 'new-repo');
    return GitRepo(path: path, name: name);
  }

  @override
  void disposeRepository(GitRepo repo) {
    // Nothing to dispose for a CLI-based service.
  }

  // ---------------------------------------------------------------------------
  // Branch Operations
  // ---------------------------------------------------------------------------

  @override
  Future<List<BranchEntity>> getBranches(GitRepo repo) async {
    return _parseBranches(repo, remote: false);
  }

  @override
  Future<List<BranchEntity>> getRemoteBranches(GitRepo repo) async {
    return _parseBranches(repo, remote: true);
  }

  Future<List<BranchEntity>> _parseBranches(
    GitRepo repo, {
    required bool remote,
  }) async {
    // Use null-byte separators for robust parsing.
    // Fields: refname, refname:short, objectname, HEAD, upstream, upstream:track
    const format =
        '%(refname)%00%(refname:short)%00%(objectname)%00%(HEAD)%00%(upstream)%00%(upstream:track)';
    final refsPrefix = remote ? 'refs/remotes/' : 'refs/heads/';
    final result = await _run(
      ['for-each-ref', '--format=$format', refsPrefix],
      workingDirectory: repo.path,
    );

    final lines = _stdout(result).trim().split('\n');
    final branches = <BranchEntity>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\x00');
      if (parts.length < 6) continue;

      final refName = parts[0];
      final shortName = parts[1];
      final sha = parts[2];
      final isHead = parts[3].trim() == '*';
      final upstream = parts[4].isNotEmpty ? parts[4] : null;

      // upstream:track looks like "[ahead 2, behind 1]" or "[ahead 2]" etc.
      int? ahead;
      int? behind;
      final trackInfo = parts[5].trim();
      if (trackInfo.isNotEmpty) {
        final aheadMatch = RegExp(r'ahead\s+(\d+)').firstMatch(trackInfo);
        final behindMatch = RegExp(r'behind\s+(\d+)').firstMatch(trackInfo);
        if (aheadMatch != null) ahead = int.parse(aheadMatch.group(1)!);
        if (behindMatch != null) behind = int.parse(behindMatch.group(1)!);
      }

      // Derive tracking branch short name from the upstream ref.
      String? trackingBranch;
      if (upstream != null && upstream.isNotEmpty) {
        trackingBranch = upstream.replaceFirst('refs/remotes/', '');
      }

      branches.add(BranchEntity(
        name: refName.replaceFirst(refsPrefix, ''),
        shortName: shortName,
        tipSha: sha,
        isHead: isHead,
        isRemote: remote,
        trackingBranch: trackingBranch,
        ahead: ahead,
        behind: behind,
      ));
    }
    return branches;
  }

  @override
  Future<BranchEntity> createBranch(
    GitRepo repo,
    String name, {
    String? startPoint,
  }) async {
    final args = ['branch', name];
    if (startPoint != null) args.add(startPoint);
    await _run(args, workingDirectory: repo.path);

    // Return the newly created branch by reading it back.
    final all = await getBranches(repo);
    return all.firstWhere((b) => b.name == name);
  }

  @override
  Future<void> deleteBranch(
    GitRepo repo,
    String name, {
    bool force = false,
  }) async {
    await _run(
      ['branch', force ? '-D' : '-d', name],
      workingDirectory: repo.path,
    );
  }

  @override
  Future<void> renameBranch(GitRepo repo, String oldName, String newName) async {
    await _run(['branch', '-m', oldName, newName], workingDirectory: repo.path);
  }

  @override
  Future<void> checkoutBranch(GitRepo repo, String name) async {
    await _run(['checkout', name], workingDirectory: repo.path);
  }

  @override
  Future<BranchEntity> getCurrentBranch(GitRepo repo) async {
    final result = await _run(
      ['symbolic-ref', '--short', 'HEAD'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    final branchName = _stdout(result).trim();
    if (result.exitCode != 0 || branchName.isEmpty) {
      // Detached HEAD – use sha instead.
      final shaResult = await _run(
        ['rev-parse', 'HEAD'],
        workingDirectory: repo.path,
      );
      final sha = _stdout(shaResult).trim();
      return BranchEntity(
        name: sha,
        shortName: sha.substring(0, 7),
        tipSha: sha,
        isHead: true,
        isRemote: false,
      );
    }

    final all = await getBranches(repo);
    return all.firstWhere(
      (b) => b.shortName == branchName || b.name == branchName,
      orElse: () => BranchEntity(
        name: branchName,
        shortName: branchName,
        tipSha: '',
        isHead: true,
        isRemote: false,
      ),
    );
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
    // Record separator to safely split multi-line messages.
    const recordSep = '---RECORD---';
    const fieldSep = '---FIELD---';
    // Fields: sha, short sha, subject, body, author name, author email,
    //         committer name, committer email, date (ISO), parent shas, decorate
    const format =
        '%H$fieldSep%h$fieldSep%s$fieldSep%b$fieldSep%an$fieldSep%ae$fieldSep%cn$fieldSep%ce$fieldSep%aI$fieldSep%P$fieldSep%D$recordSep';

    final args = ['log'];
    if (branch != null) {
      args.add(branch);
    } else {
      args.addAll(['--all', '--date-order']);
    }
    args.addAll([
      '--format=$format',
      '--skip=$offset',
      '-n',
      '$limit',
    ]);

    final result = await _run(args, workingDirectory: repo.path, allowFailure: true);
    if (result.exitCode != 0) return [];

    final raw = _stdout(result);
    final records = raw.split(recordSep);
    final commits = <CommitEntity>[];

    // Determine current HEAD sha for isHead marking.
    String? headSha;
    final headResult = await _run(
      ['rev-parse', 'HEAD'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    if (headResult.exitCode == 0) {
      headSha = _stdout(headResult).trim();
    }

    for (final record in records) {
      final trimmed = record.trim();
      if (trimmed.isEmpty) continue;
      final fields = trimmed.split(fieldSep);
      if (fields.length < 11) continue;

      final sha = fields[0].trim();
      final shortSha = fields[1].trim();
      final subject = fields[2].trim();
      final body = fields[3].trim();
      final authorName = fields[4].trim();
      final authorEmail = fields[5].trim();
      final committerName = fields[6].trim();
      final committerEmail = fields[7].trim();
      final dateStr = fields[8].trim();
      final parentStr = fields[9].trim();
      final decorateStr = fields[10].trim();

      final parentShas =
          parentStr.isEmpty ? <String>[] : parentStr.split(' ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      final message = body.isNotEmpty ? '$subject\n\n$body' : subject;

      final refs = _parseDecorateRefs(decorateStr);

      commits.add(CommitEntity(
        sha: sha,
        shortSha: shortSha,
        message: message,
        summary: subject,
        author: AuthorEntity(name: authorName, email: authorEmail),
        committer: AuthorEntity(name: committerName, email: committerEmail),
        dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
        parentShas: parentShas,
        isHead: sha == headSha,
        isMergeCommit: parentShas.length > 1,
        refs: refs,
      ));
    }
    return commits;
  }

  List<RefEntity> _parseDecorateRefs(String decorateStr) {
    if (decorateStr.isEmpty) return [];
    final refs = <RefEntity>[];
    // Format: "HEAD -> main, origin/main, tag: v1.0"
    final parts = decorateStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (var part in parts) {
      // Strip "HEAD -> " prefix
      part = part.replaceFirst(RegExp(r'^HEAD\s*->\s*'), '');
      if (part == 'HEAD') continue;

      if (part.startsWith('tag: ')) {
        refs.add(RefEntity(name: part.substring(5).trim(), type: 'tag'));
      } else if (part.contains('/')) {
        // Could be a remote ref like "origin/main"
        final slashIndex = part.indexOf('/');
        final remoteName = part.substring(0, slashIndex);
        refs.add(RefEntity(name: part, type: 'remote', remote: remoteName));
      } else {
        refs.add(RefEntity(name: part, type: 'local'));
      }
    }
    return refs;
  }

  @override
  Future<CommitEntity> getCommit(GitRepo repo, String sha) async {
    // Record separator to safely split multi-line messages.
    const recordSep = '---RECORD---';
    const fieldSep = '---FIELD---';
    // Fields: sha, short sha, subject, body, author name, author email,
    //         committer name, committer email, date (ISO), parent shas, decorate
    const format =
        '%H$fieldSep%h$fieldSep%s$fieldSep%b$fieldSep%an$fieldSep%ae$fieldSep%cn$fieldSep%ce$fieldSep%aI$fieldSep%P$fieldSep%D$recordSep';

    final result = await _run(
      ['log', '-1', '--format=$format', sha],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    if (result.exitCode != 0) {
      throw GitException('getCommit', result.exitCode, (result.stderr as String).trim());
    }

    final raw = _stdout(result);
    final records = raw.split(recordSep);

    // Determine current HEAD sha for isHead marking.
    String? headSha;
    final headResult = await _run(
      ['rev-parse', 'HEAD'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    if (headResult.exitCode == 0) {
      headSha = _stdout(headResult).trim();
    }

    for (final record in records) {
      final trimmed = record.trim();
      if (trimmed.isEmpty) continue;
      final fields = trimmed.split(fieldSep);
      if (fields.length < 11) continue;

      final commitSha = fields[0].trim();
      final shortSha = fields[1].trim();
      final subject = fields[2].trim();
      final body = fields[3].trim();
      final authorName = fields[4].trim();
      final authorEmail = fields[5].trim();
      final committerName = fields[6].trim();
      final committerEmail = fields[7].trim();
      final dateStr = fields[8].trim();
      final parentStr = fields[9].trim();
      final decorateStr = fields[10].trim();

      final parentShas =
          parentStr.isEmpty ? <String>[] : parentStr.split(' ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      final message = body.isNotEmpty ? '$subject\n\n$body' : subject;

      final refs = _parseDecorateRefs(decorateStr);

      return CommitEntity(
        sha: commitSha,
        shortSha: shortSha,
        message: message,
        summary: subject,
        author: AuthorEntity(name: authorName, email: authorEmail),
        committer: AuthorEntity(name: committerName, email: committerEmail),
        dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
        parentShas: parentShas,
        isHead: commitSha == headSha,
        isMergeCommit: parentShas.length > 1,
        refs: refs,
      );
    }
    throw GitException('getCommit', 1, 'Commit $sha not found');
  }

  @override
  Future<CommitEntity> createCommit(
    GitRepo repo,
    String message, {
    AuthorEntity? author,
    bool amend = false,
  }) async {
    final args = ['commit', '-m', message];
    if (amend) args.add('--amend');
    if (author != null) {
      args.addAll(['--author', '${author.name} <${author.email}>']);
    }
    await _run(args, workingDirectory: repo.path);

    // Read the newly created commit back.
    final commits = await getCommitHistory(repo, limit: 1);
    return commits.first;
  }

  // ---------------------------------------------------------------------------
  // Staging / Working Copy
  // ---------------------------------------------------------------------------

  @override
  Future<WorkingCopyStatus> getStatus(GitRepo repo) async {
    final result = await _run(
      ['status', '--porcelain=v1', '-uall'],
      workingDirectory: repo.path,
    );

    final staged = <FileStatusEntity>[];
    final unstaged = <FileStatusEntity>[];
    final conflicted = <FileStatusEntity>[];

    final lines = _stdout(result).split('\n');
    for (final line in lines) {
      if (line.length < 3) continue; // "XY path" is the minimum

      final indexChar = line[0]; // staging area status
      final worktreeChar = line[1]; // working tree status
      final rest = line.substring(3); // skip "XY "

      // Handle renames – path contains " -> "
      String filePath;
      String? oldPath;
      if (rest.contains(' -> ')) {
        final parts = rest.split(' -> ');
        oldPath = parts[0].trim();
        filePath = parts[1].trim();
      } else {
        filePath = rest.trim();
      }

      // Detect conflicts: UU, AA, DD, AU, UA, DU, UD
      if (_isConflict(indexChar, worktreeChar)) {
        conflicted.add(FileStatusEntity(
          path: filePath,
          status: FileChangeStatus.conflicted,
          oldPath: oldPath,
        ));
        continue;
      }

      // Untracked
      if (indexChar == '?' && worktreeChar == '?') {
        unstaged.add(FileStatusEntity(
          path: filePath,
          status: FileChangeStatus.untracked,
          isNew: true,
        ));
        continue;
      }

      // Staged changes (index char is significant)
      if (indexChar != ' ' && indexChar != '?') {
        staged.add(FileStatusEntity(
          path: filePath,
          status: _charToStatus(indexChar),
          isNew: indexChar == 'A',
          isRenamed: indexChar == 'R',
          oldPath: oldPath,
        ));
      }

      // Worktree changes (worktree char is significant)
      if (worktreeChar != ' ' && worktreeChar != '?') {
        unstaged.add(FileStatusEntity(
          path: filePath,
          status: _charToStatus(worktreeChar),
        ));
      }
    }

    return WorkingCopyStatus(
      unstagedFiles: unstaged,
      stagedFiles: staged,
      conflictedFiles: conflicted,
    );
  }

  bool _isConflict(String index, String worktree) {
    return (index == 'U' || worktree == 'U') ||
        (index == 'A' && worktree == 'A') ||
        (index == 'D' && worktree == 'D');
  }

  FileChangeStatus _charToStatus(String c) {
    switch (c) {
      case 'M':
        return FileChangeStatus.modified;
      case 'A':
        return FileChangeStatus.added;
      case 'D':
        return FileChangeStatus.deleted;
      case 'R':
        return FileChangeStatus.renamed;
      case 'C':
        return FileChangeStatus.copied;
      case 'U':
        return FileChangeStatus.conflicted;
      case '?':
        return FileChangeStatus.untracked;
      default:
        return FileChangeStatus.modified;
    }
  }

  @override
  Future<void> stageFile(GitRepo repo, String path) async {
    await _run(['add', '--', path], workingDirectory: repo.path);
  }

  @override
  Future<void> unstageFile(GitRepo repo, String path) async {
    await _run(
      ['reset', 'HEAD', '--', path],
      workingDirectory: repo.path,
      allowFailure: true,
    );
  }

  @override
  Future<void> stageAll(GitRepo repo) async {
    await _run(['add', '-A'], workingDirectory: repo.path);
  }

  @override
  Future<void> unstageAll(GitRepo repo) async {
    await _run(
      ['reset', 'HEAD'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
  }

  @override
  Future<void> discardFile(GitRepo repo, String path) async {
    // Try checkout for tracked files; use clean for untracked.
    final checkoutResult = await _run(
      ['checkout', '--', path],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    if (checkoutResult.exitCode != 0) {
      await _run(
        ['clean', '-f', '--', path],
        workingDirectory: repo.path,
      );
    }
  }

  @override
  Future<void> discardAll(GitRepo repo) async {
    await _run(['checkout', '--', '.'], workingDirectory: repo.path, allowFailure: true);
    await _run(['clean', '-fd'], workingDirectory: repo.path);
  }

  Future<List<String>> discardAllPreview(GitRepo repo) async {
    final result = await _run(['clean', '-fdn'], workingDirectory: repo.path);
    final raw = _stdout(result).trim();
    if (raw.isEmpty) return [];
    return raw.split('\n').map((line) {
      if (line.startsWith('Would remove ')) {
        return line.substring('Would remove '.length).trim();
      }
      return line.trim();
    }).toList();
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
    final args = <String>['diff', '--submodule'];
    if (staged) args.add('--cached');
    args.addAll(['--', path]);

    final result = await _run(args, workingDirectory: repo.path, allowFailure: true);
    final raw = _stdout(result);

    if (raw.trim().isEmpty) {
      // No diff (could be untracked). For untracked, diff against /dev/null.
      final untrackedResult = await _run(
        ['diff', '--no-index', '/dev/null', path],
        workingDirectory: repo.path,
        allowFailure: true,
      );
      final untrackedRaw = _stdout(untrackedResult);
      if (untrackedRaw.trim().isEmpty) {
        return FileDiffEntity(
          path: path,
          status: FileChangeStatus.modified,
          hunks: const [],
          isBinary: false,
          addedLines: 0,
          deletedLines: 0,
        );
      }
      return _parseSingleFileDiff(untrackedRaw, fallbackPath: path);
    }

    return _parseSingleFileDiff(raw, fallbackPath: path);
  }

  @override
  Future<List<FileDiffEntity>> getCommitDiff(GitRepo repo, String sha) async {
    // For the root commit (no parents), diff against an empty tree.
    final commitResult = await _run(
      ['rev-parse', '$sha^'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    final List<String> args;
    if (commitResult.exitCode != 0) {
      // Root commit – diff against empty tree.
      const emptyTree = '4b825dc642cb6eb9a060e54bf899d69f7cb46901';
      args = ['diff', emptyTree, sha];
    } else {
      args = ['diff', '$sha^', sha];
    }

    final result = await _run(args, workingDirectory: repo.path);
    final raw = _stdout(result);
    return _parseMultiFileDiff(raw);
  }

  @override
  Future<FileDiffEntity> getFileDiffForCommit(
    GitRepo repo,
    String sha,
    String path,
  ) async {
    final commitResult = await _run(
      ['rev-parse', '$sha^'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    final List<String> args;
    if (commitResult.exitCode != 0) {
      const emptyTree = '4b825dc642cb6eb9a060e54bf899d69f7cb46901';
      args = ['diff', emptyTree, sha, '--', path];
    } else {
      args = ['diff', '$sha^', sha, '--', path];
    }

    final result = await _run(args, workingDirectory: repo.path, allowFailure: true);
    final raw = _stdout(result);
    if (raw.trim().isEmpty) {
      return FileDiffEntity(
        path: path,
        status: FileChangeStatus.modified,
        hunks: const [],
        isBinary: false,
        addedLines: 0,
        deletedLines: 0,
      );
    }
    return _parseSingleFileDiff(raw, fallbackPath: path);
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
    final result = await _run(
      ['tag', '-l', '--format=%(refname:short)%00%(objectname)%00%(objecttype)%00%(contents:subject)'],
      workingDirectory: repo.path,
    );
    final raw = _stdout(result).trim();
    if (raw.isEmpty) return [];

    final lines = raw.split('\n');
    final tags = <TagEntity>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\x00');
      if (parts.length < 4) continue;
      final name = parts[0].trim();
      final sha = parts[1].trim();
      final objType = parts[2].trim();
      final subject = parts[3].trim();
      final isAnnotated = objType == 'tag';
      tags.add(TagEntity(
        name: name,
        sha: sha,
        message: isAnnotated && subject.isNotEmpty ? subject : null,
        isAnnotated: isAnnotated,
      ));
    }
    return tags;
  }

  @override
  Future<TagEntity> createTag(
    GitRepo repo,
    String name, {
    String? target,
    String? message,
  }) async {
    final args = ['tag'];
    if (message != null) {
      args.addAll(['-a', name, '-m', message]);
    } else {
      args.add(name);
    }
    if (target != null) args.add(target);
    await _run(args, workingDirectory: repo.path);

    // Read back.
    final tags = await getTags(repo);
    return tags.firstWhere((t) => t.name == name);
  }

  @override
  Future<void> deleteTag(GitRepo repo, String name) async {
    await _run(['tag', '-d', name], workingDirectory: repo.path);
  }

  // ---------------------------------------------------------------------------
  // Stashes
  // ---------------------------------------------------------------------------

  @override
  Future<List<StashEntity>> getStashes(GitRepo repo) async {
    final result = await _run(
      ['stash', 'list', '--format=%H%x00%gd%x00%gs%x00%aI'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    final raw = _stdout(result).trim();
    if (raw.isEmpty) return [];

    final lines = raw.split('\n');
    final stashes = <StashEntity>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('\x00');
      if (parts.length < 4) continue;
      final sha = parts[0].trim();
      final ref = parts[1].trim(); // e.g. "stash@{0}"
      final message = parts[2].trim();
      final dateStr = parts[3].trim();

      // Extract index from stash@{N}
      final indexMatch = RegExp(r'stash@\{(\d+)\}').firstMatch(ref);
      final index = indexMatch != null ? int.parse(indexMatch.group(1)!) : stashes.length;

      stashes.add(StashEntity(
        index: index,
        message: message,
        sha: sha,
        dateTime: DateTime.tryParse(dateStr) ?? DateTime.now(),
      ));
    }
    return stashes;
  }

  @override
  Future<StashEntity> createStash(
    GitRepo repo, {
    String? message,
    bool includeUntracked = false,
  }) async {
    final args = ['stash', 'push'];
    if (message != null) args.addAll(['-m', message]);
    if (includeUntracked) args.add('--include-untracked');
    await _run(args, workingDirectory: repo.path);

    final stashes = await getStashes(repo);
    return stashes.first;
  }

  @override
  Future<void> applyStash(GitRepo repo, int index) async {
    await _run(['stash', 'apply', 'stash@{$index}'], workingDirectory: repo.path);
  }

  @override
  Future<void> dropStash(GitRepo repo, int index) async {
    await _run(['stash', 'drop', 'stash@{$index}'], workingDirectory: repo.path);
  }

  @override
  Future<void> popStash(GitRepo repo, int index) async {
    await _run(['stash', 'pop', 'stash@{$index}'], workingDirectory: repo.path);
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
    final statusResult = await _run(
      ['submodule', 'status'],
      workingDirectory: repo.path,
      allowFailure: true,
    );
    if (statusResult.exitCode != 0) return [];
    
    final pathsMap = await _getSubmodulePaths(repo.path);
    final urlsMap = await _getSubmoduleUrls(repo.path);
    
    // Create reverse map: path -> name
    final pathToName = <String, String>{};
    pathsMap.forEach((name, path) {
      pathToName[path.replaceAll('\\', '/')] = name;
    });
    
    final lines = LineSplitter.split(statusResult.stdout as String);
    final submodules = <SubmoduleEntity>[];
    
    for (final line in lines) {
      if (line.length < 42) continue;
      final statusChar = line.substring(0, 1);
      final sha = line.substring(1, 41);
      var pathAndMore = line.substring(42).trim();
      var path = pathAndMore;
      if (pathAndMore.contains(' (')) {
        final index = pathAndMore.lastIndexOf(' (');
        path = pathAndMore.substring(0, index);
      }
      
      final normalizedPath = path.replaceAll('\\', '/');
      final name = pathToName[normalizedPath] ?? path.split('/').last;
      final url = urlsMap[name] ?? '';
      
      SubmoduleStatus status;
      bool isInitialized = true;
      if (statusChar == '-') {
        status = SubmoduleStatus.uninitialized;
        isInitialized = false;
      } else if (statusChar == '+') {
        status = SubmoduleStatus.modified;
      } else if (statusChar == ' ') {
        status = SubmoduleStatus.clean;
      } else {
        status = SubmoduleStatus.clean;
      }
      
      submodules.add(SubmoduleEntity(
        name: name,
        path: path,
        url: url,
        sha: sha,
        status: status,
        isInitialized: isInitialized,
      ));
    }
    return submodules;
  }

  @override
  Future<void> initSubmodules(GitRepo repo) async {
    await _run(['submodule', 'init'], workingDirectory: repo.path);
  }

  @override
  Future<void> updateSubmodules(GitRepo repo) async {
    await _run(['submodule', 'update', '--init', '--recursive'], workingDirectory: repo.path);
  }

  @override
  Future<void> syncSubmodules(GitRepo repo) async {
    await _run(['submodule', 'sync'], workingDirectory: repo.path);
  }
}

/// Internal helper for collecting remote fetch/push URLs.
class _RemoteUrls {
  String? fetchUrl;
  String? pushUrl;
}
