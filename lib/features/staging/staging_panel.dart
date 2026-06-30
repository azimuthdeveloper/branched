import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import '../diff_viewer/diff_viewer_bloc.dart';
import '../diff_viewer/diff_panel.dart';
import 'staging_bloc.dart';

class StagingPanel extends StatefulWidget {
  final GitRepo repo;

  const StagingPanel({super.key, required this.repo});

  @override
  State<StagingPanel> createState() => _StagingPanelState();
}

class _StagingPanelState extends State<StagingPanel> {
  final _summaryController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedFilePath;
  bool _selectedIsStaged = false;

  @override
  void initState() {
    super.initState();
    context.read<StagingBloc>().add(LoadWorkingCopyEvent(widget.repo));
  }

  void _onFileSelected(String path, bool isStaged) {
    setState(() {
      _selectedFilePath = path;
      _selectedIsStaged = isStaged;
    });
    context.read<DiffViewerBloc>().add(
          LoadFileDiffEvent(repo: widget.repo, path: path, staged: isStaged),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StagingBloc, StagingState>(
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Row(
          children: [
            // Left pane: staging lists and commit message
            Container(
              width: 320,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: FurcateTheme.darkBorder, width: 1)),
              ),
              child: Column(
                children: [
                  // Unstaged Files header
                  _buildListHeader(
                    'Unstaged Changes',
                    state.unstagedFiles.length,
                    onAction: () => context.read<StagingBloc>().add(StageAllEvent(widget.repo)),
                    actionText: 'Stage All',
                  ),

                  // Unstaged Files List
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.unstagedFiles.length,
                      itemBuilder: (context, index) {
                        final file = state.unstagedFiles[index];
                        return _buildFileRow(file, false);
                      },
                    ),
                  ),

                  const Divider(color: FurcateTheme.darkBorder, height: 1),

                  // Staged Files header
                  _buildListHeader(
                    'Staged Changes',
                    state.stagedFiles.length,
                    onAction: () => context.read<StagingBloc>().add(UnstageAllEvent(widget.repo)),
                    actionText: 'Unstage All',
                  ),

                  // Staged Files List
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.stagedFiles.length,
                      itemBuilder: (context, index) {
                        final file = state.stagedFiles[index];
                        return _buildFileRow(file, true);
                      },
                    ),
                  ),

                  const Divider(color: FurcateTheme.darkBorder, height: 1),

                  // Commit Form Area
                  _buildCommitForm(context, state),
                ],
              ),
            ),

            // Right pane: diff viewer
            Expanded(
              child: _selectedFilePath == null
                  ? const Center(
                      child: Text(
                        'Select a file to view changes.',
                        style: TextStyle(color: FurcateTheme.darkTextSecondary),
                      ),
                    )
                  : DiffPanel(repo: widget.repo),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListHeader(String title, int count, {required VoidCallback onAction, required String actionText}) {
    return Container(
      height: 28,
      color: FurcateTheme.darkBgTitlebar,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            '$title ($count)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary),
          ),
          const Spacer(),
          if (count > 0)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              child: Text(
                actionText,
                style: const TextStyle(fontSize: 10, color: FurcateTheme.darkAccent, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileRow(FileStatusEntity file, bool isStaged) {
    final isSelected = _selectedFilePath == file.path && _selectedIsStaged == isStaged;

    Color statusColor;
    String statusChar;

    switch (file.status) {
      case FileChangeStatus.added:
      case FileChangeStatus.untracked:
        statusColor = FurcateTheme.diffAddText;
        statusChar = 'A';
        break;
      case FileChangeStatus.deleted:
        statusColor = FurcateTheme.diffDelText;
        statusChar = 'D';
        break;
      default:
        statusColor = Colors.orange;
        statusChar = 'M';
    }

    return GestureDetector(
      onTap: () => _onFileSelected(file.path, isStaged),
      child: Container(
        height: 28,
        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Status Indicator Icon
            Container(
              width: 14,
              height: 14,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                statusChar,
                style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),

            // File path text
            Expanded(
              child: Text(
                file.path,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextPrimary),
              ),
            ),

            // Quick Stage/Unstage button
            IconButton(
              icon: Icon(isStaged ? Icons.remove : Icons.add, size: 14, color: FurcateTheme.darkTextSecondary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                if (isStaged) {
                  context.read<StagingBloc>().add(UnstageFileEvent(widget.repo, file.path));
                } else {
                  context.read<StagingBloc>().add(StageFileEvent(widget.repo, file.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitForm(BuildContext context, StagingState state) {
    final canCommit = state.stagedFiles.isNotEmpty && _summaryController.text.trim().isNotEmpty;

    return Container(
      color: FurcateTheme.darkBgToolbar,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary field
          TextField(
            controller: _summaryController,
            style: const TextStyle(fontSize: 12),
            onChanged: (val) {
              setState(() {});
            },
            decoration: const InputDecoration(
              hintText: 'Commit summary (required)',
              hintStyle: TextStyle(color: FurcateTheme.darkTextSecondary, fontSize: 12),
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 8),

          // Description field
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              hintText: 'Description...',
              hintStyle: TextStyle(color: FurcateTheme.darkTextSecondary, fontSize: 11),
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(8),
            ),
          ),
          const SizedBox(height: 10),

          // Commit button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FurcateTheme.darkAccent,
              disabledBackgroundColor: FurcateTheme.darkBorder,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: canCommit
                ? () {
                    context.read<StagingBloc>().add(
                          CommitChangesEvent(
                            widget.repo,
                            _summaryController.text.trim(),
                            body: _descriptionController.text.trim(),
                          ),
                        );
                    _summaryController.clear();
                    _descriptionController.clear();
                    setState(() {
                      _selectedFilePath = null;
                    });
                  }
                : null,
            child: state.isCommitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Commit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
