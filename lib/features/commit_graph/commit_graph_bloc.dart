import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import 'graph_layout.dart';

abstract class CommitGraphEvent extends Equatable {
  const CommitGraphEvent();
  @override
  List<Object?> get props => [];
}

class LoadCommitHistoryEvent extends CommitGraphEvent {
  final GitRepo repo;
  final String? branch;
  const LoadCommitHistoryEvent(this.repo, {this.branch});
  @override
  List<Object?> get props => [repo, branch];
}

class SelectCommitEvent extends CommitGraphEvent {
  final CommitEntity? commit;
  const SelectCommitEvent(this.commit);
  @override
  List<Object?> get props => [commit];
}

class SearchGraphCommitsEvent extends CommitGraphEvent {
  final String query;
  const SearchGraphCommitsEvent(this.query);
  @override
  List<Object?> get props => [query];
}

class CommitGraphState extends Equatable {
  final List<GraphCommit> allCommits;
  final List<GraphCommit> visibleCommits;
  final CommitEntity? selectedCommit;
  final String? branchFilter;
  final String searchQuery;
  final bool isLoading;

  const CommitGraphState({
    this.allCommits = const [],
    this.visibleCommits = const [],
    this.selectedCommit,
    this.branchFilter,
    this.searchQuery = '',
    this.isLoading = false,
  });

  CommitGraphState copyWith({
    List<GraphCommit>? allCommits,
    List<GraphCommit>? visibleCommits,
    CommitEntity? selectedCommit,
    String? branchFilter,
    String? searchQuery,
    bool? isLoading,
  }) {
    return CommitGraphState(
      allCommits: allCommits ?? this.allCommits,
      visibleCommits: visibleCommits ?? this.visibleCommits,
      selectedCommit: selectedCommit ?? this.selectedCommit,
      branchFilter: branchFilter ?? this.branchFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [allCommits, visibleCommits, selectedCommit, branchFilter, searchQuery, isLoading];
}

class CommitGraphBloc extends Bloc<CommitGraphEvent, CommitGraphState> {
  final GitService _gitService;

  CommitGraphBloc(this._gitService) : super(const CommitGraphState()) {
    on<LoadCommitHistoryEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, branchFilter: event.branch));
      try {
        final commits = await _gitService.getCommitHistory(event.repo, branch: event.branch);
        final layout = GraphLayoutBuilder.buildLayout(commits);

        emit(state.copyWith(
          allCommits: layout,
          visibleCommits: layout,
          isLoading: false,
        ));
      } catch (_) {
        emit(state.copyWith(isLoading: false));
      }
    });

    on<SelectCommitEvent>((event, emit) {
      emit(state.copyWith(selectedCommit: event.commit));
    });

    on<SearchGraphCommitsEvent>((event, emit) {
      final query = event.query.trim().toLowerCase();
      if (query.isEmpty) {
        emit(state.copyWith(visibleCommits: state.allCommits, searchQuery: ''));
        return;
      }

      // Flatten search hits: a filtered subset cannot reuse full-graph edges.
      final filtered = state.allCommits
          .where((gc) {
            return gc.commit.message.toLowerCase().contains(query) ||
                gc.commit.sha.toLowerCase().contains(query) ||
                gc.commit.author.name.toLowerCase().contains(query);
          })
          .map(
            (gc) => GraphCommit(
              commit: gc.commit,
              laneIndex: 0,
              connections: const [],
              colorIndex: 0,
            ),
          )
          .toList();

      emit(state.copyWith(visibleCommits: filtered, searchQuery: event.query));
    });
  }
}
