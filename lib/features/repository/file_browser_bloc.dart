import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';

// Events
abstract class FileBrowserEvent extends Equatable {
  const FileBrowserEvent();
  @override
  List<Object?> get props => [];
}

class LoadFileTreeEvent extends FileBrowserEvent {
  final GitRepo repo;
  final String? ref;
  const LoadFileTreeEvent(this.repo, {this.ref});
  @override
  List<Object?> get props => [repo, ref];
}

class SelectFileEvent extends FileBrowserEvent {
  final GitRepo repo;
  final String path;
  final String? ref;
  const SelectFileEvent(this.repo, this.path, {this.ref});
  @override
  List<Object?> get props => [repo, path, ref];
}

class CommitFileEvent extends FileBrowserEvent {
  final GitRepo repo;
  final String path;
  final String content;
  final String message;
  final void Function()? onSuccess;
  
  const CommitFileEvent({
    required this.repo,
    required this.path,
    required this.content,
    required this.message,
    this.onSuccess,
  });

  @override
  List<Object?> get props => [repo, path, content, message, onSuccess];
}

// State
class FileBrowserState extends Equatable {
  final bool isLoading;
  final List<String> files;
  final String? selectedFilePath;
  final String? selectedFileContent;
  final bool isSaving;
  final String? error;

  const FileBrowserState({
    this.isLoading = false,
    this.files = const [],
    this.selectedFilePath,
    this.selectedFileContent,
    this.isSaving = false,
    this.error,
  });

  FileBrowserState copyWith({
    bool? isLoading,
    List<String>? files,
    String? selectedFilePath,
    String? selectedFileContent,
    bool? isSaving,
    String? error,
  }) {
    return FileBrowserState(
      isLoading: isLoading ?? this.isLoading,
      files: files ?? this.files,
      selectedFilePath: selectedFilePath ?? this.selectedFilePath,
      selectedFileContent: selectedFileContent ?? this.selectedFileContent,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, files, selectedFilePath, selectedFileContent, isSaving, error];
}

// BLoC
class FileBrowserBloc extends Bloc<FileBrowserEvent, FileBrowserState> {
  final GitService _gitService;

  FileBrowserBloc(this._gitService) : super(const FileBrowserState()) {
    on<LoadFileTreeEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, selectedFilePath: null, selectedFileContent: null));
      try {
        final files = await _gitService.getTreeFiles(event.repo, ref: event.ref);
        emit(state.copyWith(isLoading: false, files: files));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: 'Failed to load file tree: $e'));
      }
    });

    on<SelectFileEvent>((event, emit) async {
      emit(state.copyWith(isLoading: true, error: null, selectedFilePath: event.path, selectedFileContent: null));
      try {
        final content = await _gitService.getFileContentAtRef(event.repo, event.path, ref: event.ref);
        emit(state.copyWith(isLoading: false, selectedFileContent: content));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: 'Failed to load file content: $e'));
      }
    });

    on<CommitFileEvent>((event, emit) async {
      emit(state.copyWith(isSaving: true, error: null));
      try {
        await _gitService.writeAndCommitFile(event.repo, event.path, event.content, event.message);
        emit(state.copyWith(isSaving: false, selectedFileContent: event.content));
        event.onSuccess?.call();
      } catch (e) {
        emit(state.copyWith(isSaving: false, error: 'Failed to commit changes: $e'));
      }
    });
  }
}
