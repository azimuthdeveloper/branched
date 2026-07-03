import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../core/locator.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import '../sidebar/sidebar_bloc.dart';
import '../commit_graph/commit_graph_bloc.dart';
import 'file_browser_bloc.dart';

class FileBrowserPanel extends StatelessWidget {
  final GitRepo repo;

  const FileBrowserPanel({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FileBrowserBloc>(
      create: (context) => FileBrowserBloc(locator<GitService>())
        ..add(LoadFileTreeEvent(repo)),
      child: BlocListener<SidebarBloc, SidebarState>(
        listener: (context, sidebarState) {
          // If selected item (branch/tag) changes, reload tree at that reference
          final ref = (sidebarState.selectedItem.type == SidebarItemType.branch ||
                  sidebarState.selectedItem.type == SidebarItemType.remoteBranch)
              ? sidebarState.selectedItem.refName
              : null;
          context.read<FileBrowserBloc>().add(LoadFileTreeEvent(repo, ref: ref));
        },
        child: Container(
          color: FurcateTheme.darkBgPrimary,
          child: Row(
            children: [
              // Left Pane: File List
              Expanded(
                flex: 2,
                child: _FileListPane(repo: repo),
              ),

              // Divider
              const VerticalDivider(color: FurcateTheme.darkBorder, width: 1),

              // Right Pane: Editor / Content Viewer
              Expanded(
                flex: 3,
                child: _FileEditorPane(repo: repo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileListPane extends StatelessWidget {
  final GitRepo repo;

  const _FileListPane({required this.repo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: FurcateTheme.darkBgSecondary,
            border: Border(bottom: BorderSide(color: FurcateTheme.darkBorder)),
          ),
          alignment: Alignment.centerLeft,
          child: const Row(
            children: [
              Icon(Icons.folder_open, size: 16, color: FurcateTheme.darkTextSecondary),
              SizedBox(width: 8),
              Text(
                'REPOSITORY FILES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: FurcateTheme.darkTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),

        // Files List
        Expanded(
          child: BlocBuilder<FileBrowserBloc, FileBrowserState>(
            builder: (context, state) {
              if (state.isLoading && state.files.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.error != null && state.files.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (state.files.isEmpty) {
                return const Center(
                  child: Text(
                    'No files found in this repository.',
                    style: TextStyle(color: FurcateTheme.darkTextSecondary, fontSize: 12),
                  ),
                );
              }

              return ListView.builder(
                itemCount: state.files.length,
                itemBuilder: (context, index) {
                  final path = state.files[index];
                  final isSelected = state.selectedFilePath == path;

                  return InkWell(
                    onTap: () {
                      final sidebarState = context.read<SidebarBloc>().state;
                      final ref = (sidebarState.selectedItem.type == SidebarItemType.branch ||
                              sidebarState.selectedItem.type == SidebarItemType.remoteBranch)
                          ? sidebarState.selectedItem.refName
                          : null;
                      context.read<FileBrowserBloc>().add(SelectFileEvent(repo, path, ref: ref));
                    },
                    child: Container(
                      height: 32,
                      color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.insert_drive_file, size: 14, color: FurcateTheme.darkTextSecondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              path,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? FurcateTheme.darkTextEmphasis : FurcateTheme.darkTextPrimary,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FileEditorPane extends StatelessWidget {
  final GitRepo repo;
  final TextEditingController _editorController = TextEditingController();

  _FileEditorPane({required this.repo});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileBrowserBloc, FileBrowserState>(
      builder: (context, state) {
        if (state.selectedFilePath == null) {
          return const Center(
            child: Text(
              'Select a file from the repository to view or edit.',
              style: TextStyle(color: FurcateTheme.darkTextSecondary, fontSize: 12),
            ),
          );
        }

        if (state.isLoading && state.selectedFileContent == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Set content if loaded and editor is empty or file changed
        final content = state.selectedFileContent ?? '';
        if (_editorController.text != content) {
          _editorController.text = content;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Editor Header
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: FurcateTheme.darkBgSecondary,
                border: Border(bottom: BorderSide(color: FurcateTheme.darkBorder)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      state.selectedFilePath!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FurcateTheme.darkTextEmphasis,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FurcateTheme.darkAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: state.isSaving
                        ? null
                        : () => _showCommitDialog(context, state.selectedFilePath!),
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 14),
                    label: const Text('Commit Changes', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),

            // Editor Text Area
            Expanded(
              child: Container(
                color: FurcateTheme.darkBgPrimary,
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _editorController,
                  maxLines: null,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: FurcateTheme.darkTextPrimary,
                    height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCommitDialog(BuildContext context, String filePath) {
    final commitMsgController = TextEditingController();
    final browserBloc = context.read<FileBrowserBloc>();
    final graphBloc = context.read<CommitGraphBloc>();

    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Commit Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Commit changes directly to $filePath',
              style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commitMsgController,
              decoration: const InputDecoration(
                hintText: 'Enter commit message...',
                hintStyle: TextStyle(fontSize: 12),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: FurcateTheme.darkAccent),
            onPressed: () {
              final msg = commitMsgController.text.trim();
              if (msg.isNotEmpty) {
                browserBloc.add(CommitFileEvent(
                  repo: repo,
                  path: filePath,
                  content: _editorController.text,
                  message: msg,
                  onSuccess: () {
                    // Reload commit history graph and details
                    graphBloc.add(LoadCommitHistoryEvent(repo));
                  },
                ));
              }
              Navigator.pop(diagContext);
            },
            child: const Text('Commit'),
          ),
        ],
      ),
    );
  }
}
