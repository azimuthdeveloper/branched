import 'package:equatable/equatable.dart';

enum FileChangeStatus { modified, added, deleted, renamed, copied, conflicted, untracked }

enum DiffLineOrigin { context, addition, deletion }

enum ConnectionType { straight, mergeLeft, mergeRight, branchLeft, branchRight }

class AuthorEntity extends Equatable {
  final String name;
  final String email;

  const AuthorEntity({required this.name, required this.email});

  @override
  List<Object?> get props => [name, email];
}

/// Username/password (or PAT) pair supplied by the user for remote auth.
class GitAuthCredentials extends Equatable {
  final String username;
  final String password;

  const GitAuthCredentials({required this.username, required this.password});

  @override
  List<Object?> get props => [username, password];
}

class RefEntity extends Equatable {
  final String name;
  final String type; // 'local', 'remote', 'tag'
  final String? remote;

  const RefEntity({required this.name, required this.type, this.remote});

  @override
  List<Object?> get props => [name, type, remote];
}

class CommitEntity extends Equatable {
  final String sha;
  final String shortSha;
  final String message;
  final String summary;
  final AuthorEntity author;
  final AuthorEntity committer;
  final DateTime dateTime;
  final List<String> parentShas;
  final bool isHead;
  final bool isMergeCommit;
  final List<RefEntity> refs;

  const CommitEntity({
    required this.sha,
    required this.shortSha,
    required this.message,
    required this.summary,
    required this.author,
    required this.committer,
    required this.dateTime,
    required this.parentShas,
    required this.isHead,
    required this.isMergeCommit,
    required this.refs,
  });

  @override
  List<Object?> get props => [sha, shortSha, message, summary, author, committer, dateTime, parentShas, isHead, isMergeCommit, refs];
}

class BranchEntity extends Equatable {
  final String name;
  final String shortName;
  final String tipSha;
  final bool isHead;
  final bool isRemote;
  final String? trackingBranch;
  final int? ahead;
  final int? behind;

  const BranchEntity({
    required this.name,
    required this.shortName,
    required this.tipSha,
    required this.isHead,
    required this.isRemote,
    this.trackingBranch,
    this.ahead,
    this.behind,
  });

  @override
  List<Object?> get props => [name, shortName, tipSha, isHead, isRemote, trackingBranch, ahead, behind];
}

class RemoteEntity extends Equatable {
  final String name;
  final String url;
  final String? pushUrl;

  const RemoteEntity({required this.name, required this.url, this.pushUrl});

  @override
  List<Object?> get props => [name, url, pushUrl];
}

class TagEntity extends Equatable {
  final String name;
  final String sha;
  final String? message;
  final bool isAnnotated;

  const TagEntity({required this.name, required this.sha, this.message, required this.isAnnotated});

  @override
  List<Object?> get props => [name, sha, message, isAnnotated];
}

class StashEntity extends Equatable {
  final int index;
  final String message;
  final String sha;
  final DateTime dateTime;

  const StashEntity({required this.index, required this.message, required this.sha, required this.dateTime});

  @override
  List<Object?> get props => [index, message, sha, dateTime];
}

class DiffLineEntity extends Equatable {
  final String content;
  final DiffLineOrigin origin;
  final int? oldLineNumber;
  final int? newLineNumber;

  const DiffLineEntity({
    required this.content,
    required this.origin,
    this.oldLineNumber,
    this.newLineNumber,
  });

  @override
  List<Object?> get props => [content, origin, oldLineNumber, newLineNumber];
}

class DiffHunkEntity extends Equatable {
  final int oldStart;
  final int oldLines;
  final int newStart;
  final int newLines;
  final String header;
  final List<DiffLineEntity> lines;

  const DiffHunkEntity({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.header,
    required this.lines,
  });

  @override
  List<Object?> get props => [oldStart, oldLines, newStart, newLines, header, lines];
}

class FileDiffEntity extends Equatable {
  final String path;
  final String? oldPath;
  final FileChangeStatus status;
  final List<DiffHunkEntity> hunks;
  final bool isBinary;
  final int addedLines;
  final int deletedLines;

  const FileDiffEntity({
    required this.path,
    this.oldPath,
    required this.status,
    required this.hunks,
    required this.isBinary,
    required this.addedLines,
    required this.deletedLines,
  });

  @override
  List<Object?> get props => [path, oldPath, status, hunks, isBinary, addedLines, deletedLines];
}

class FileStatusEntity extends Equatable {
  final String path;
  final FileChangeStatus status;
  final bool isNew;
  final bool isRenamed;
  final String? oldPath;

  const FileStatusEntity({
    required this.path,
    required this.status,
    this.isNew = false,
    this.isRenamed = false,
    this.oldPath,
  });

  @override
  List<Object?> get props => [path, status, isNew, isRenamed, oldPath];
}

class WorkingCopyStatus extends Equatable {
  final List<FileStatusEntity> unstagedFiles;
  final List<FileStatusEntity> stagedFiles;
  final List<FileStatusEntity> conflictedFiles;

  const WorkingCopyStatus({
    required this.unstagedFiles,
    required this.stagedFiles,
    required this.conflictedFiles,
  });

  bool get hasChanges => unstagedFiles.isNotEmpty || stagedFiles.isNotEmpty || conflictedFiles.isNotEmpty;

  @override
  List<Object?> get props => [unstagedFiles, stagedFiles, conflictedFiles];
}

class GraphConnectionEntity extends Equatable {
  final int fromLane;
  final int toLane;
  final ConnectionType type;
  final int colorIndex;

  const GraphConnectionEntity({
    required this.fromLane,
    required this.toLane,
    required this.type,
    required this.colorIndex,
  });

  @override
  List<Object?> get props => [fromLane, toLane, type, colorIndex];
}

class GraphNodeEntity extends Equatable {
  final String sha;
  final int laneIndex;
  final List<GraphConnectionEntity> connections;
  final int colorIndex;

  const GraphNodeEntity({
    required this.sha,
    required this.laneIndex,
    required this.connections,
    required this.colorIndex,
  });

  @override
  List<Object?> get props => [sha, laneIndex, connections, colorIndex];
}

enum SubmoduleStatus { clean, modified, uninitialized, outOfDate }

class SubmoduleEntity extends Equatable {
  final String name;
  final String path;
  final String url;
  final String sha;
  final SubmoduleStatus status;
  final bool isInitialized;

  const SubmoduleEntity({
    required this.name,
    required this.path,
    required this.url,
    required this.sha,
    required this.status,
    required this.isInitialized,
  });

  @override
  List<Object?> get props => [name, path, url, sha, status, isInitialized];
}

