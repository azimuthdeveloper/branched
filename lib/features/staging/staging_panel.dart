import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    HardwareKeyboard.instance.addHandler(_handleStagingKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleStagingKey);
    _summaryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool _handleStagingKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isCmdOrCtrl = isControlPressed || isMetaPressed;

    if (isCmdOrCtrl && event.logicalKey == LogicalKeyboardKey.enter) {
      _triggerCommit();
      return true;
    }

    return false;
  }

  void _triggerCommit() {
    final state = context.read<StagingBloc>().state;
    final canCommit = state.stagedFiles.isNotEmpty && _summaryController.text.trim().isNotEmpty;
    if (canCommit && !state.isCommitting) {
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

  Future<void> _openInEditor(String filePath) async {
    try {
      if (Platform.isAndroid) {
        await _showAndroidTextEditor(filePath);
        return;
      }

      if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', filePath], runInShell: true);
      } else {
        // Linux
        await Process.run('xdg-open', [filePath]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open file: $e')),
        );
      }
    }
  }

  Future<void> _showAndroidTextEditor(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File does not exist locally.')),
        );
      }
      return;
    }

    String initialContent = '';
    try {
      initialContent = await file.readAsString();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read file: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    final controller = TextEditingController(text: initialContent);

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: FurcateTheme.darkBgPrimary,
          appBar: AppBar(
            backgroundColor: FurcateTheme.darkBgTitlebar,
            title: Text(
              filePath.split('/').last,
              style: const TextStyle(fontSize: 14, color: FurcateTheme.darkTextEmphasis),
            ),
            leading: IconButton(
              icon: const Icon(Icons.close, color: FurcateTheme.darkTextPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  try {
                    await file.writeAsString(controller.text);
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File saved successfully.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save file: $e')),
                      );
                    }
                  }
                },
                child: const Text(
                  'Save',
                  style: TextStyle(
                    color: FurcateTheme.darkAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: FurcateTheme.darkTextPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Enter file contents...',
                hintStyle: TextStyle(color: FurcateTheme.darkTextSecondary),
              ),
            ),
          ),
        );
      },
    );

    // Refresh working copy after editor closes
    if (mounted) {
      context.read<StagingBloc>().add(LoadWorkingCopyEvent(widget.repo));
    }
  }

  void _showFileContextMenu(BuildContext context, TapDownDetails details, FileStatusEntity file, bool isStaged) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: isStaged
          ? [
              const PopupMenuItem<String>(
                value: 'unstage',
                child: Text('Unstage File', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem<String>(
                value: 'open',
                child: Text('Open in Editor', style: TextStyle(fontSize: 12)),
              ),
            ]
          : [
              const PopupMenuItem<String>(
                value: 'stage',
                child: Text('Stage File', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem<String>(
                value: 'discard',
                child: Text('Discard Changes', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem<String>(
                value: 'open',
                child: Text('Open in Editor', style: TextStyle(fontSize: 12)),
              ),
            ],
    ).then((value) async {
      if (value == null) return;

      final stagingBloc = context.read<StagingBloc>();

      switch (value) {
        case 'stage':
          stagingBloc.add(StageFileEvent(widget.repo, file.path));
          break;
        case 'unstage':
          stagingBloc.add(UnstageFileEvent(widget.repo, file.path));
          break;
        case 'discard':
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Discard Changes'),
              content: Text('Are you sure you want to discard changes in "${file.path}"? This cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Discard', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
          if (confirm == true) {
            stagingBloc.add(DiscardChangesEvent(widget.repo, file.path));
          }
          break;
        case 'open':
          await _openInEditor('${widget.repo.path}/${file.path}');
          break;
      }
    });
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
          Expanded(
            child: Text(
              '$title ($count)',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: FurcateTheme.darkTextSecondary,
              ),
            ),
          ),
          if (count > 0)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 10,
                  color: FurcateTheme.darkAccent,
                  fontWeight: FontWeight.bold,
                ),
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
      onSecondaryTapDown: (details) => _showFileContextMenu(context, details, file, isStaged),
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
