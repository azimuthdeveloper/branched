import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';

abstract class StagingEvent extends Equatable {
  const StagingEvent();
  @override
  List<Object?> get props => [];
}

class LoadWorkingCopyEvent extends StagingEvent {
  final GitRepo repo;
  const LoadWorkingCopyEvent(this.repo);
  @override
  List<Object?> get props => [repo];
}

class StageFileEvent extends StagingEvent {
  final GitRepo repo;
  final String path;
  const StageFileEvent(this.repo, this.path);
  @override
  List<Object?> get props => [repo, path];
}

class UnstageFileEvent extends StagingEvent {
  final GitRepo repo;
  final String path;
  const UnstageFileEvent(this.repo, this.path);
  @override
  List<Object?> get props => [repo, path];
}

class StageAllEvent extends StagingEvent {
  final GitRepo repo;
  const StageAllEvent(this.repo);
  @override
  List<Object?> get props => [repo];
}

class UnstageAllEvent extends StagingEvent {
  final GitRepo repo;
  const UnstageAllEvent(this.repo);
  @override
  List<Object?> get props => [repo];
}

class DiscardChangesEvent extends StagingEvent {
  final GitRepo repo;
  final String path;
  const DiscardChangesEvent(this.repo, this.path);
  @override
  List<Object?> get props => [repo, path];
}

class UpdateCommitMessageEvent extends StagingEvent {
  final String message;
  const UpdateCommitMessageEvent(this.message);
  @override
  List<Object?> get props => [message];
}

class CommitChangesEvent extends StagingEvent {
  final GitRepo repo;
  final String summary;
  final String? body;
  const CommitChangesEvent(this.repo, this.summary, {this.body});
  @override
  List<Object?> get props => [repo, summary, body];
}

class StagingState extends Equatable {
  final List<FileStatusEntity> unstagedFiles;
  final List<FileStatusEntity> stagedFiles;
  final String commitMessage;
  final bool isLoading;
  final bool isCommitting;
  final String? error;

  const StagingState({
    this.unstagedFiles = const [],
    this.stagedFiles = const [],
    this.commitMessage = '',
    this.isLoading = false,
    this.isCommitting = false,
    this.error,
  });

  StagingState copyWith({
    List<FileStatusEntity>? unstagedFiles,
    List<FileStatusEntity>? stagedFiles,
    String? commitMessage,
    bool? isLoading,
    bool? isCommitting,
    String? error,
  }) {
    return StagingState(
      unstagedFiles: unstagedFiles ?? this.unstagedFiles,
      stagedFiles: stagedFiles ?? this.stagedFiles,
      commitMessage: commitMessage ?? this.commitMessage,
      isLoading: isLoading ?? this.isLoading,
      isCommitting: isCommitting ?? this.isCommitting,
      error: error,
    );
  }

  @override
  List<Object?> get props => [unstagedFiles, stagedFiles, commitMessage, isLoading, isCommitting, error];
}

class StagingBloc extends Bloc<StagingEvent, StagingState> {
  final GitService _gitService;

  StagingBloc(this._gitService) : super(const StagingState()) {
    on<LoadWorkingCopyEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final status = await _gitService.getStatus(event.repo);
        emit(state.copyWith(
          unstagedFiles: status.unstagedFiles,
          stagedFiles: status.stagedFiles,
          isLoading: false,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<StageFileEvent>((event, emit) async {
      try {
        await _gitService.stageFile(event.repo, event.path);
        add(LoadWorkingCopyEvent(event.repo));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<UnstageFileEvent>((event, emit) async {
      try {
        await _gitService.unstageFile(event.repo, event.path);
        add(LoadWorkingCopyEvent(event.repo));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<StageAllEvent>((event, emit) async {
      try {
        await _gitService.stageAll(event.repo);
        add(LoadWorkingCopyEvent(event.repo));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<UnstageAllEvent>((event, emit) async {
      try {
        await _gitService.unstageAll(event.repo);
        add(LoadWorkingCopyEvent(event.repo));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<DiscardChangesEvent>((event, emit) async {
      try {
        await _gitService.discardFile(event.repo, event.path);
        add(LoadWorkingCopyEvent(event.repo));
      } catch (e) {
        emit(state.copyWith(error: e.toString()));
      }
    });

    on<UpdateCommitMessageEvent>((event, emit) {
      emit(state.copyWith(commitMessage: event.message));
    });

    on<CommitChangesEvent>((event, emit) async {
      if (state.stagedFiles.isEmpty) return;
      emit(state.copyWith(isCommitting: true));
      try {
        final message = event.body != null && event.body!.isNotEmpty
            ? '${event.summary}\n\n${event.body}'
            : event.summary;
        await _gitService.createCommit(event.repo, message);
        emit(state.copyWith(
          isCommitting: false,
          commitMessage: '',
        ));
        add(LoadWorkingCopyEvent(event.repo));
      } catch (e) {
        emit(state.copyWith(isCommitting: false, error: e.toString()));
      }
    });
  }
}
