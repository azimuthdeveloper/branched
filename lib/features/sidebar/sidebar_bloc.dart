import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';

enum SidebarItemType { changes, branch, remoteBranch, tag, stash }

class SidebarItem extends Equatable {
  final String label;
  final SidebarItemType type;
  final String? refName;
  final int? index;

  const SidebarItem({
    required this.label,
    required this.type,
    this.refName,
    this.index,
  });

  @override
  List<Object?> get props => [label, type, refName, index];
}

abstract class SidebarEvent extends Equatable {
  const SidebarEvent();
  @override
  List<Object?> get props => [];
}

class LoadSidebarEvent extends SidebarEvent {
  final GitRepo repo;
  const LoadSidebarEvent(this.repo);
  @override
  List<Object?> get props => [repo];
}

class SelectSidebarItemEvent extends SidebarEvent {
  final SidebarItem item;
  const SelectSidebarItemEvent(this.item);
  @override
  List<Object?> get props => [item];
}

class SidebarState extends Equatable {
  final List<BranchEntity> localBranches;
  final List<BranchEntity> remoteBranches;
  final List<TagEntity> tags;
  final List<StashEntity> stashes;
  final List<SubmoduleEntity> submodules;
  final SidebarItem selectedItem;
  final bool isLoading;

  const SidebarState({
    this.localBranches = const [],
    this.remoteBranches = const [],
    this.tags = const [],
    this.stashes = const [],
    this.submodules = const [],
    this.selectedItem = const SidebarItem(label: 'Changes', type: SidebarItemType.changes),
    this.isLoading = false,
  });

  SidebarState copyWith({
    List<BranchEntity>? localBranches,
    List<BranchEntity>? remoteBranches,
    List<TagEntity>? tags,
    List<StashEntity>? stashes,
    List<SubmoduleEntity>? submodules,
    SidebarItem? selectedItem,
    bool? isLoading,
  }) {
    return SidebarState(
      localBranches: localBranches ?? this.localBranches,
      remoteBranches: remoteBranches ?? this.remoteBranches,
      tags: tags ?? this.tags,
      stashes: stashes ?? this.stashes,
      submodules: submodules ?? this.submodules,
      selectedItem: selectedItem ?? this.selectedItem,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [localBranches, remoteBranches, tags, stashes, submodules, selectedItem, isLoading];
}

class SidebarBloc extends Bloc<SidebarEvent, SidebarState> {
  final GitService _gitService;

  SidebarBloc(this._gitService) : super(const SidebarState()) {
    on<LoadSidebarEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true));
      try {
        final local = await _gitService.getBranches(event.repo);
        final remote = await _gitService.getRemoteBranches(event.repo);
        final tags = await _gitService.getTags(event.repo);
        final stashes = await _gitService.getStashes(event.repo);
        final submodules = await _gitService.getSubmodules(event.repo);

        emit(state.copyWith(
          localBranches: local,
          remoteBranches: remote,
          tags: tags,
          stashes: stashes,
          submodules: submodules,
          isLoading: false,
        ));
      } catch (_) {
        emit(state.copyWith(isLoading: false));
      }
    });

    on<SelectSidebarItemEvent>((event, emit) {
      emit(state.copyWith(selectedItem: event.item));
    });
  }
}
