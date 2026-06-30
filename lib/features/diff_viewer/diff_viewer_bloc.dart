import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';

enum DiffMode { unified, split }

abstract class DiffViewerEvent extends Equatable {
  const DiffViewerEvent();
  @override
  List<Object?> get props => [];
}

class LoadFileDiffEvent extends DiffViewerEvent {
  final GitRepo repo;
  final String path;
  final bool staged;
  final String? commitSha;

  const LoadFileDiffEvent({
    required this.repo,
    required this.path,
    this.staged = false,
    this.commitSha,
  });

  @override
  List<Object?> get props => [repo, path, staged, commitSha];
}

class ToggleDiffModeEvent extends DiffViewerEvent {
  final DiffMode mode;
  const ToggleDiffModeEvent(this.mode);
  @override
  List<Object?> get props => [mode];
}

class ClearDiffEvent extends DiffViewerEvent {}

class DiffViewerState extends Equatable {
  final FileDiffEntity? diff;
  final DiffMode mode;
  final bool isLoading;
  final String? error;

  const DiffViewerState({
    this.diff,
    this.mode = DiffMode.unified,
    this.isLoading = false,
    this.error,
  });

  DiffViewerState copyWith({
    FileDiffEntity? diff,
    DiffMode? mode,
    bool? isLoading,
    String? error,
  }) {
    return DiffViewerState(
      diff: diff ?? this.diff,
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [diff, mode, isLoading, error];
}

class DiffViewerBloc extends Bloc<DiffViewerEvent, DiffViewerState> {
  final GitService _gitService;

  DiffViewerBloc(this._gitService) : super(const DiffViewerState()) {
    on<LoadFileDiffEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, diff: null));
      try {
        FileDiffEntity diff;
        if (event.commitSha != null) {
          diff = await _gitService.getFileDiffForCommit(event.repo, event.commitSha!, event.path);
        } else {
          diff = await _gitService.getWorkingDiff(event.repo, event.path, staged: event.staged);
        }
        emit(state.copyWith(diff: diff, isLoading: false));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });

    on<ToggleDiffModeEvent>((event, emit) {
      emit(state.copyWith(mode: event.mode));
    });

    on<ClearDiffEvent>((event, emit) {
      emit(const DiffViewerState());
    });
  }
}
