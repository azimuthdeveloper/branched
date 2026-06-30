import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_service.dart';

class RepoTab extends Equatable {
  final String id;
  final String path;
  final String name;
  final bool isDirty;

  const RepoTab({
    required this.id,
    required this.path,
    required this.name,
    this.isDirty = false,
  });

  RepoTab copyWith({bool? isDirty}) {
    return RepoTab(
      id: id,
      path: path,
      name: name,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [id, path, name, isDirty];
}

abstract class RepositoryManagerEvent extends Equatable {
  const RepositoryManagerEvent();
  @override
  List<Object?> get props => [];
}

class OpenRepositoryEvent extends RepositoryManagerEvent {
  final String path;
  const OpenRepositoryEvent(this.path);
  @override
  List<Object?> get props => [path];
}

class CloseRepositoryEvent extends RepositoryManagerEvent {
  final int index;
  const CloseRepositoryEvent(this.index);
  @override
  List<Object?> get props => [index];
}

class SwitchTabEvent extends RepositoryManagerEvent {
  final int index;
  const SwitchTabEvent(this.index);
  @override
  List<Object?> get props => [index];
}

class SetDirtyTabEvent extends RepositoryManagerEvent {
  final String path;
  final bool isDirty;
  const SetDirtyTabEvent(this.path, this.isDirty);
  @override
  List<Object?> get props => [path, isDirty];
}

class RepositoryManagerState extends Equatable {
  final List<RepoTab> openTabs;
  final int activeTabIndex;
  final List<String> recentRepos;

  const RepositoryManagerState({
    this.openTabs = const [],
    this.activeTabIndex = -1,
    this.recentRepos = const [],
  });

  RepositoryManagerState copyWith({
    List<RepoTab>? openTabs,
    int? activeTabIndex,
    List<String>? recentRepos,
  }) {
    return RepositoryManagerState(
      openTabs: openTabs ?? this.openTabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
      recentRepos: recentRepos ?? this.recentRepos,
    );
  }

  RepoTab? get activeTab => activeTabIndex >= 0 && activeTabIndex < openTabs.length ? openTabs[activeTabIndex] : null;

  @override
  List<Object?> get props => [openTabs, activeTabIndex, recentRepos];
}

class RepositoryManagerBloc extends Bloc<RepositoryManagerEvent, RepositoryManagerState> {
  final GitService _gitService;

  RepositoryManagerBloc(this._gitService) : super(const RepositoryManagerState()) {
    on<OpenRepositoryEvent>((event, emit) async {
      // Check if already open
      final existingIndex = state.openTabs.indexWhere((t) => t.path == event.path);
      if (existingIndex != -1) {
        emit(state.copyWith(activeTabIndex: existingIndex));
        return;
      }

      try {
        final repo = await _gitService.openRepository(event.path);
        final tab = RepoTab(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          path: repo.path,
          name: repo.name,
        );

        final updatedTabs = List<RepoTab>.from(state.openTabs)..add(tab);
        final updatedRecent = List<String>.from(state.recentRepos)
          ..remove(event.path)
          ..insert(0, event.path);

        emit(state.copyWith(
          openTabs: updatedTabs,
          activeTabIndex: updatedTabs.length - 1,
          recentRepos: updatedRecent,
        ));
      } catch (_) {
        // Handle error
      }
    });

    on<CloseRepositoryEvent>((event, emit) {
      if (event.index < 0 || event.index >= state.openTabs.length) return;
      
      final updatedTabs = List<RepoTab>.from(state.openTabs)..removeAt(event.index);
      var newIndex = state.activeTabIndex;
      if (newIndex >= updatedTabs.length) {
        newIndex = updatedTabs.length - 1;
      }

      emit(state.copyWith(
        openTabs: updatedTabs,
        activeTabIndex: newIndex,
      ));
    });

    on<SwitchTabEvent>((event, emit) {
      if (event.index < 0 || event.index >= state.openTabs.length) return;
      emit(state.copyWith(activeTabIndex: event.index));
    });

    on<SetDirtyTabEvent>((event, emit) {
      final tabIndex = state.openTabs.indexWhere((t) => t.path == event.path);
      if (tabIndex != -1) {
        final updatedTabs = List<RepoTab>.from(state.openTabs);
        updatedTabs[tabIndex] = updatedTabs[tabIndex].copyWith(isDirty: event.isDirty);
        emit(state.copyWith(openTabs: updatedTabs));
      }
    });
  }
}
