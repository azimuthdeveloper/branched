import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/theme.dart';
import '../../core/locator.dart';
import '../../core/file_picker_service.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import '../repository_manager/repository_manager_bloc.dart';
import '../repository/repository_bloc.dart';
import '../commit_graph/commit_graph_bloc.dart';
import '../staging/staging_bloc.dart';
import 'sidebar_bloc.dart';

class SidebarWidget extends StatefulWidget {
  final GitRepo repo;
  const SidebarWidget({super.key, required this.repo});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  final Map<String, bool> _isExpanded = {
    'Branches': true,
    'Remotes': true,
    'Submodules': false,
    'Tags': false,
    'Stashes': false,
  };

  String _filterQuery = '';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final isControlPressed = HardwareKeyboard.instance.isControlPressed;
    final isMetaPressed = HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final isCmdOrCtrl = isControlPressed || isMetaPressed;
    final key = event.logicalKey;

    if (isCmdOrCtrl) {
      if (key == LogicalKeyboardKey.keyO) {
        if (isShiftPressed) {
          _showCloneRepoDialog(context);
        } else {
          _openRepository(context);
        }
        return true;
      } else if (key == LogicalKeyboardKey.keyW && !isShiftPressed) {
        _closeCurrentTab(context);
        return true;
      } else if (key == LogicalKeyboardKey.keyA && isShiftPressed) {
        context.read<StagingBloc>().add(StageAllEvent(widget.repo));
        return true;
      } else if (key == LogicalKeyboardKey.keyP && isShiftPressed) {
        _pushRepository(context);
        return true;
      } else if (key == LogicalKeyboardKey.keyF && isShiftPressed) {
        _fetchRepository(context);
        return true;
      } else if (key == LogicalKeyboardKey.keyL && isShiftPressed) {
        _pullRepository(context);
        return true;
      }
    } else if (key == LogicalKeyboardKey.f5) {
      _refreshAll(context);
      return true;
    }

    return false;
  }

  void _openRepository(BuildContext context) async {
    final selectedDir = await locator<FilePickerService>().getDirectoryPath(
      dialogTitle: 'Open Git Repository',
    );
    if (selectedDir == null) return;
    if (!context.mounted) return;
    context.read<RepositoryManagerBloc>().add(OpenRepositoryEvent(selectedDir));
  }

  void _closeCurrentTab(BuildContext context) {
    final repoManager = context.read<RepositoryManagerBloc>();
    final activeIndex = repoManager.state.activeTabIndex;
    if (activeIndex != -1) {
      repoManager.add(CloseRepositoryEvent(activeIndex));
    }
  }

  void _pushRepository(BuildContext context) async {
    final gitService = locator<GitService>();
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pushing changes...'), duration: Duration(seconds: 1)),
      );
      await gitService.push(widget.repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push completed successfully.')),
        );
        _refreshAll(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Push failed: $e')),
        );
      }
    }
  }

  void _fetchRepository(BuildContext context) async {
    final gitService = locator<GitService>();
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fetching changes...'), duration: Duration(seconds: 1)),
      );
      await gitService.fetch(widget.repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fetch completed successfully.')),
        );
        _refreshAll(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fetch failed: $e')),
        );
      }
    }
  }

  void _pullRepository(BuildContext context) async {
    final gitService = locator<GitService>();
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pulling changes...'), duration: Duration(seconds: 1)),
      );
      await gitService.pull(widget.repo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pull completed successfully.')),
        );
        _refreshAll(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pull failed: $e')),
        );
      }
    }
  }

  void _refreshAll(BuildContext context) {
    context.read<SidebarBloc>().add(LoadSidebarEvent(widget.repo));
    context.read<RepositoryBloc>().add(const RefreshRepositoryEvent());
    context.read<StagingBloc>().add(LoadWorkingCopyEvent(widget.repo));
    final commitGraphState = context.read<CommitGraphBloc>().state;
    context.read<CommitGraphBloc>().add(LoadCommitHistoryEvent(widget.repo, branch: commitGraphState.branchFilter));
  }

  String _getRepoNameFromUrl(String url) {
    if (url.isEmpty) return '';
    var cleaned = url.trim();
    if (cleaned.endsWith('.git')) {
      cleaned = cleaned.substring(0, cleaned.length - 4);
    }
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    final index = cleaned.lastIndexOf('/');
    if (index != -1) {
      return cleaned.substring(index + 1);
    }
    return cleaned;
  }

  void _showCloneRepoDialog(BuildContext context) {
    final urlController = TextEditingController();
    final pathController = TextEditingController();
    String baseDir = '';

    if (Platform.isAndroid) {
      getApplicationDocumentsDirectory().then((dir) {
        baseDir = dir.path;
        pathController.text = p.join(baseDir, '');
      });
    }

    urlController.addListener(() {
      final url = urlController.text.trim();
      final repoName = _getRepoNameFromUrl(url);
      if (Platform.isAndroid && baseDir.isNotEmpty) {
        pathController.text = p.join(baseDir, repoName);
      }
    });

    showDialog(
      context: context,
      builder: (diagContext) {
        return AlertDialog(
          backgroundColor: FurcateTheme.darkBgSecondary,
          title: const Text('Clone Repository', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Remote URL',
                  hintText: 'https://github.com/user/repo.git',
                  labelStyle: TextStyle(color: FurcateTheme.darkTextSecondary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pathController,
                      decoration: const InputDecoration(
                        labelText: 'Local Path',
                        labelStyle: TextStyle(color: FurcateTheme.darkTextSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!Platform.isAndroid)
                    IconButton(
                      icon: const Icon(Icons.folder_open, color: FurcateTheme.darkAccent),
                      tooltip: 'Browse...',
                      onPressed: () async {
                        final dir = await locator<FilePickerService>().getDirectoryPath(
                          dialogTitle: 'Select Clone Destination',
                        );
                        if (dir != null) {
                          pathController.text = dir;
                        }
                      },
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, color: FurcateTheme.darkAccent),
                      tooltip: 'Reset to default documents path',
                      onPressed: () {
                        if (baseDir.isNotEmpty) {
                          final url = urlController.text.trim();
                          final repoName = _getRepoNameFromUrl(url);
                          pathController.text = p.join(baseDir, repoName);
                        }
                      },
                    ),
                ],
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 12),
                const Text(
                  'Note: On Android, repositories must be stored in the app\'s internal documents folder to support Git filesystem operations without OS permission restrictions.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: FurcateTheme.darkTextSecondary,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagContext),
              child: const Text('Cancel', style: TextStyle(color: FurcateTheme.darkTextSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: FurcateTheme.darkAccent),
              onPressed: () {
                final url = urlController.text.trim();
                final path = pathController.text.trim();
                if (url.isNotEmpty && path.isNotEmpty) {
                  context.read<RepositoryManagerBloc>().add(CloneRepositoryEvent(url, path));
                }
                Navigator.pop(diagContext);
              },
              child: const Text('Clone'),
            ),
          ],
        );
      },
    );
  }

  void _showLocalBranchContextMenu(BuildContext context, TapDownDetails details, BranchEntity branch) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'checkout',
          child: Text('Checkout Branch', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'merge',
          child: Text('Merge into Current', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete Branch', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'rename',
          child: Text('Rename Branch', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'push',
          child: Text('Push Branch', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Text('Copy Branch Name', style: TextStyle(fontSize: 12)),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      final gitService = locator<GitService>();
      final sidebarBloc = context.read<SidebarBloc>();

      try {
        switch (value) {
          case 'checkout':
            await gitService.checkoutBranch(widget.repo, branch.name);
            if (mounted) {
              sidebarBloc.add(SelectSidebarItemEvent(SidebarItem(
                label: branch.shortName,
                type: SidebarItemType.branch,
                refName: branch.name,
              )));
            }
            break;
          case 'merge':
            await gitService.merge(widget.repo, branch.name);
            break;
          case 'delete':
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Branch'),
                content: Text('Are you sure you want to delete branch "${branch.shortName}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await gitService.deleteBranch(widget.repo, branch.name);
            }
            break;
          case 'rename':
            final textController = TextEditingController(text: branch.shortName);
            final newName = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Rename Branch'),
                content: TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: 'New branch name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
                    child: const Text('Rename'),
                  ),
                ],
              ),
            );
            if (newName != null && newName.isNotEmpty) {
              await gitService.renameBranch(widget.repo, branch.name, newName);
            }
            break;
          case 'push':
            await gitService.push(widget.repo, branch: branch.name);
            break;
          case 'copy':
            await Clipboard.setData(ClipboardData(text: branch.shortName));
            break;
        }

        _refreshAll(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e')),
          );
        }
      }
    });
  }

  void _showRemoteBranchContextMenu(BuildContext context, TapDownDetails details, BranchEntity branch) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'checkout_as_local',
          child: Text('Checkout as Local Branch', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete Remote Branch', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Text('Copy Branch Name', style: TextStyle(fontSize: 12)),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      final gitService = locator<GitService>();
      final sidebarBloc = context.read<SidebarBloc>();

      try {
        switch (value) {
          case 'checkout_as_local':
            String defaultLocalName = branch.shortName;
            final slashIdx = branch.shortName.indexOf('/');
            if (slashIdx != -1) {
              defaultLocalName = branch.shortName.substring(slashIdx + 1);
            }

            final textController = TextEditingController(text: defaultLocalName);
            final localName = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Checkout as Local Branch'),
                content: TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: 'Local branch name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
                    child: const Text('Checkout'),
                  ),
                ],
              ),
            );

            if (localName != null && localName.isNotEmpty) {
              await gitService.createBranch(widget.repo, localName, startPoint: branch.name);
              await gitService.checkoutBranch(widget.repo, localName);
              if (mounted) {
                sidebarBloc.add(SelectSidebarItemEvent(SidebarItem(
                  label: localName,
                  type: SidebarItemType.branch,
                  refName: localName,
                )));
              }
            }
            break;
          case 'delete':
            final parts = branch.shortName.split('/');
            final remote = parts.first;
            final remoteBranchName = parts.sublist(1).join('/');

            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Remote Branch'),
                content: Text('Are you sure you want to delete remote branch "${branch.shortName}"? This will push deletion to the remote.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await gitService.push(widget.repo, remote: remote, branch: ':$remoteBranchName');
            }
            break;
          case 'copy':
            await Clipboard.setData(ClipboardData(text: branch.shortName));
            break;
        }

        _refreshAll(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e')),
          );
        }
      }
    });
  }

  void _showTagContextMenu(BuildContext context, TapDownDetails details, TagEntity tag) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'checkout',
          child: Text('Checkout Tag', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Text('Delete Tag', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Text('Copy Tag Name', style: TextStyle(fontSize: 12)),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      final gitService = locator<GitService>();

      try {
        switch (value) {
          case 'checkout':
            await gitService.checkoutBranch(widget.repo, tag.name);
            break;
          case 'delete':
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Tag'),
                content: Text('Are you sure you want to delete tag "${tag.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await gitService.deleteTag(widget.repo, tag.name);
            }
            break;
          case 'copy':
            await Clipboard.setData(ClipboardData(text: tag.name));
            break;
        }

        _refreshAll(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e')),
          );
        }
      }
    });
  }

  void _showStashContextMenu(BuildContext context, TapDownDetails details, StashEntity stash) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'apply',
          child: Text('Apply Stash', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'pop',
          child: Text('Pop Stash', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'drop',
          child: Text('Drop Stash', style: TextStyle(fontSize: 12)),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      final gitService = locator<GitService>();

      try {
        switch (value) {
          case 'apply':
            await gitService.applyStash(widget.repo, stash.index);
            break;
          case 'pop':
            await gitService.popStash(widget.repo, stash.index);
            break;
          case 'drop':
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Drop Stash'),
                content: Text('Are you sure you want to drop stash@{${stash.index}}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Drop', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await gitService.dropStash(widget.repo, stash.index);
            }
            break;
        }

        _refreshAll(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: FurcateTheme.darkBgSidebar,
      child: Column(
        children: [
          // Filter branches bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: FurcateTheme.darkBgSecondary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: FurcateTheme.darkBorder),
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _filterQuery = val.toLowerCase();
                  });
                },
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Filter branches...',
                  hintStyle: TextStyle(color: FurcateTheme.darkTextSecondary, fontSize: 12),
                  prefixIcon: Icon(Icons.search, size: 14, color: FurcateTheme.darkTextSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.only(bottom: 12),
                ),
              ),
            ),
          ),

          // Sidebar Sections
          Expanded(
            child: BlocBuilder<SidebarBloc, SidebarState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                return ListView(
                  children: [
                    // Changes section
                    _buildChangesRow(state),

                    // Files section
                    _buildFilesRow(state),

                    const Divider(color: FurcateTheme.darkBorder, height: 1),

                    // Branches section
                    _buildSectionHeader('Branches'),
                    if (_isExpanded['Branches']!)
                      ...state.localBranches
                          .where((b) => b.name.toLowerCase().contains(_filterQuery))
                          .map((b) => _buildBranchRow(b, state.selectedItem)),

                    // Remotes section
                    _buildSectionHeader('Remotes'),
                    if (_isExpanded['Remotes']!)
                      ...state.remoteBranches
                          .where((b) => b.name.toLowerCase().contains(_filterQuery))
                          .map((b) => _buildBranchRow(b, state.selectedItem)),

                    // Submodules section
                    _buildSectionHeader('Submodules', badge: state.submodules.length),
                    if (_isExpanded['Submodules']!)
                      ...state.submodules
                          .where((s) => s.name.toLowerCase().contains(_filterQuery))
                          .map((s) => _buildSubmoduleRow(s, state.selectedItem)),

                    // Tags section
                    _buildSectionHeader('Tags', badge: state.tags.length),
                    if (_isExpanded['Tags']!)
                      ...state.tags
                          .where((t) => t.name.toLowerCase().contains(_filterQuery))
                          .map((t) => _buildTagRow(t, state.selectedItem)),

                    // Stashes section
                    _buildSectionHeader('Stashes', badge: state.stashes.length),
                    if (_isExpanded['Stashes']!)
                      ...state.stashes
                          .map((s) => _buildStashRow(s, state.selectedItem)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangesRow(SidebarState state) {
    final isSelected = state.selectedItem.type == SidebarItemType.changes;
    return GestureDetector(
      onTap: () {
        context.read<SidebarBloc>().add(
              const SelectSidebarItemEvent(
                SidebarItem(label: 'Changes', type: SidebarItemType.changes),
              ),
            );
      },
      child: Container(
        height: 28,
        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Row(
          children: [
            Icon(Icons.edit_note, size: 16, color: FurcateTheme.darkTextPrimary),
            SizedBox(width: 8),
            Text(
              'Changes',
              style: TextStyle(fontSize: 12, color: FurcateTheme.darkTextEmphasis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesRow(SidebarState state) {
    final isSelected = state.selectedItem.type == SidebarItemType.files;
    return GestureDetector(
      onTap: () {
        context.read<SidebarBloc>().add(
              const SelectSidebarItemEvent(
                SidebarItem(label: 'Files', type: SidebarItemType.files),
              ),
            );
      },
      child: Container(
        height: 28,
        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: const Row(
          children: [
            Icon(Icons.folder_open, size: 16, color: FurcateTheme.darkTextPrimary),
            SizedBox(width: 8),
            Text(
              'Files',
              style: TextStyle(fontSize: 12, color: FurcateTheme.darkTextEmphasis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {int? badge}) {
    final isExpanded = _isExpanded[title] ?? false;
    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpanded[title] = !isExpanded;
        });
      },
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
              size: 16,
              color: FurcateTheme.darkTextSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: FurcateTheme.darkTextSecondary,
              ),
            ),
            const Spacer(),
            if (badge != null && badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: FurcateTheme.darkBgSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(fontSize: 9, color: FurcateTheme.darkTextSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchRow(BranchEntity branch, SidebarItem selectedItem) {
    final isSelected = selectedItem.type == (branch.isRemote ? SidebarItemType.remoteBranch : SidebarItemType.branch) &&
        selectedItem.refName == branch.name;

    return GestureDetector(
      onTap: () {
        context.read<SidebarBloc>().add(
              SelectSidebarItemEvent(
                SidebarItem(
                  label: branch.shortName,
                  type: branch.isRemote ? SidebarItemType.remoteBranch : SidebarItemType.branch,
                  refName: branch.name,
                ),
              ),
            );
      },
      onSecondaryTapDown: (details) {
        if (branch.isRemote) {
          _showRemoteBranchContextMenu(context, details, branch);
        } else {
          _showLocalBranchContextMenu(context, details, branch);
        }
      },
      child: Container(
        height: 24,
        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
        padding: const EdgeInsets.only(left: 24, right: 12),
        child: Row(
          children: [
            Icon(
              branch.isRemote ? Icons.cloud_queue : Icons.call_split,
              size: 14,
              color: branch.isHead ? FurcateTheme.darkAccent : FurcateTheme.darkTextSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                branch.shortName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: branch.isHead ? FurcateTheme.darkTextEmphasis : FurcateTheme.darkTextPrimary,
                  fontWeight: branch.isHead ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (branch.isHead)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: FurcateTheme.darkAccent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagRow(TagEntity tag, SidebarItem selectedItem) {
    final isSelected = selectedItem.type == SidebarItemType.tag && selectedItem.refName == tag.name;

    return GestureDetector(
      onTap: () {
        context.read<SidebarBloc>().add(
              SelectSidebarItemEvent(
                SidebarItem(label: tag.name, type: SidebarItemType.tag, refName: tag.name),
              ),
            );
      },
      onSecondaryTapDown: (details) {
        _showTagContextMenu(context, details, tag);
      },
      child: Container(
        height: 24,
        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
        padding: const EdgeInsets.only(left: 24, right: 12),
        child: Row(
          children: [
            const Icon(Icons.sell, size: 12, color: FurcateTheme.darkTextSecondary),
            const SizedBox(width: 8),
            Text(
              tag.name,
              style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStashRow(StashEntity stash, SidebarItem selectedItem) {
    final isSelected = selectedItem.type == SidebarItemType.stash && selectedItem.index == stash.index;

    return GestureDetector(
      onTap: () {
        context.read<SidebarBloc>().add(
              SelectSidebarItemEvent(
                SidebarItem(label: stash.message, type: SidebarItemType.stash, index: stash.index),
              ),
            );
      },
      onSecondaryTapDown: (details) {
        _showStashContextMenu(context, details, stash);
      },
      child: Container(
        height: 24,
        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
        padding: const EdgeInsets.only(left: 24, right: 12),
        child: Row(
          children: [
            const Icon(Icons.archive_outlined, size: 13, color: FurcateTheme.darkTextSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'stash@{${stash.index}}: ${stash.message}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmoduleContextMenu(BuildContext context, TapDownDetails details, SubmoduleEntity submodule) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      items: [
        const PopupMenuItem<String>(
          value: 'init',
          child: Text('Init Submodule', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'update',
          child: Text('Update Submodule', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'sync',
          child: Text('Sync Submodule', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'open',
          child: Text('Open Submodule in New Tab', style: TextStyle(fontSize: 12)),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      final gitService = locator<GitService>();
      final sidebarBloc = context.read<SidebarBloc>();

      try {
        switch (value) {
          case 'init':
            await gitService.initSubmodules(widget.repo);
            break;
          case 'update':
            await gitService.updateSubmodules(widget.repo);
            break;
          case 'sync':
            await gitService.syncSubmodules(widget.repo);
            break;
          case 'open':
            final absolutePath = '${widget.repo.path}/${submodule.path}';
            if (mounted) {
              context.read<RepositoryManagerBloc>().add(OpenRepositoryEvent(absolutePath));
            }
            break;
        }

        // Reload the sidebar after operation
        sidebarBloc.add(LoadSidebarEvent(widget.repo));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Submodule operation failed: $e')),
          );
        }
      }
    });
  }

  Widget _buildSubmoduleRow(SubmoduleEntity submodule, SidebarItem selectedItem) {
    IconData statusIcon;
    Color statusColor;
    switch (submodule.status) {
      case SubmoduleStatus.clean:
        statusIcon = Icons.check_circle_outline;
        statusColor = Colors.green;
        break;
      case SubmoduleStatus.modified:
        statusIcon = Icons.warning_amber_rounded;
        statusColor = Colors.orange;
        break;
      case SubmoduleStatus.uninitialized:
        statusIcon = Icons.error_outline;
        statusColor = Colors.red;
        break;
      case SubmoduleStatus.outOfDate:
        statusIcon = Icons.sync;
        statusColor = Colors.blue;
        break;
    }

    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showSubmoduleContextMenu(context, details, submodule);
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 24, right: 4),
        child: Row(
          children: [
            Icon(
              statusIcon,
              size: 13,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message: 'Path: ${submodule.path}\nSHA: ${submodule.sha}\nURL: ${submodule.url}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      submodule.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextPrimary, height: 1.1),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${submodule.sha.length >= 7 ? submodule.sha.substring(0, 7) : submodule.sha} • ${submodule.path}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 9, color: FurcateTheme.darkTextSecondary, height: 1.1),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTapDown: (details) {
                _showSubmoduleContextMenu(context, details, submodule);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.more_vert,
                  size: 14,
                  color: FurcateTheme.darkTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
