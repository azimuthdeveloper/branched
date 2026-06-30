import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';

abstract class RepositoryEvent extends Equatable {
  const RepositoryEvent();
  @override
  List<Object?> get props => [];
}

class LoadRepositoryDetailsEvent extends RepositoryEvent {
  final String path;
  const LoadRepositoryDetailsEvent(this.path);
  @override
  List<Object?> get props => [path];
}

class RefreshRepositoryEvent extends RepositoryEvent {
  const RefreshRepositoryEvent();
}

abstract class RepositoryState extends Equatable {
  const RepositoryState();
  @override
  List<Object?> get props => [];
}

class RepositoryInitial extends RepositoryState {}

class RepositoryLoading extends RepositoryState {}

class RepositoryLoaded extends RepositoryState {
  final GitRepo repo;
  final BranchEntity currentBranch;
  final CommitEntity? headCommit;
  final bool hasUncommittedChanges;

  const RepositoryLoaded({
    required this.repo,
    required this.currentBranch,
    this.headCommit,
    required this.hasUncommittedChanges,
  });

  @override
  List<Object?> get props => [repo, currentBranch, headCommit, hasUncommittedChanges];
}

class RepositoryError extends RepositoryState {
  final String message;
  const RepositoryError(this.message);
  @override
  List<Object?> get props => [message];
}

class RepositoryBloc extends Bloc<RepositoryEvent, RepositoryState> {
  final GitService _gitService;
  GitRepo? _activeRepo;

  RepositoryBloc(this._gitService) : super(RepositoryInitial()) {
    on<LoadRepositoryDetailsEvent>((event, emit) async {
      emit(RepositoryLoading());
      try {
        final repo = await _gitService.openRepository(event.path);
        _activeRepo = repo;
        await _loadRepoInfo(repo, emit);
      } catch (e) {
        emit(RepositoryError(e.toString()));
      }
    });

    on<RefreshRepositoryEvent>((event, emit) async {
      if (_activeRepo == null) return;
      try {
        await _loadRepoInfo(_activeRepo!, emit);
      } catch (e) {
        emit(RepositoryError(e.toString()));
      }
    });
  }

  Future<void> _loadRepoInfo(GitRepo repo, Emitter<RepositoryState> emit) async {
    final currentBranch = await _gitService.getCurrentBranch(repo);
    final history = await _gitService.getCommitHistory(repo, branch: currentBranch.name, limit: 1);
    final headCommit = history.isNotEmpty ? history.first : null;
    final status = await _gitService.getStatus(repo);

    emit(RepositoryLoaded(
      repo: repo,
      currentBranch: currentBranch,
      headCommit: headCommit,
      hasUncommittedChanges: status.hasChanges,
    ));
  }
}
