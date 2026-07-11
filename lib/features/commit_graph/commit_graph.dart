import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../core/locator.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import '../sidebar/sidebar_bloc.dart';
import '../repository/repository_bloc.dart';
import '../staging/staging_bloc.dart';
import 'commit_graph_bloc.dart';
import 'commit_graph_painter.dart';

class CommitGraphWidget extends StatefulWidget {
  final GitRepo repo;

  const CommitGraphWidget({super.key, required this.repo});

  @override
  State<CommitGraphWidget> createState() => _CommitGraphWidgetState();
}

class _CommitGraphWidgetState extends State<CommitGraphWidget> {
  final _searchController = TextEditingController();
  final _graphScrollController = ScrollController();
  final _listScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _graphScrollController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _showCommitContextMenu(BuildContext context, TapDownDetails details, CommitEntity commit) {
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
          value: 'cherrypick',
          child: Text('Cherry-pick Commit', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'revert',
          child: Text('Revert Commit', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'reset',
          child: Text('Reset to Commit', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'branch',
          child: Text('Create Branch Here', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<String>(
          value: 'tag',
          child: Text('Create Tag Here', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'copy',
          child: Text('Copy SHA', style: TextStyle(fontSize: 12)),
        ),
      ],
    ).then((value) async {
      if (value == null) return;

      // Use the workspace repo handle — do not depend on RepositoryBloc
      // having finished loading (context menus used to silently no-op).
      final repo = widget.repo;
      final gitService = locator<GitService>();

      try {
        switch (value) {
          case 'cherrypick':
            await gitService.cherryPick(repo, commit.sha);
            break;
          case 'revert':
            await gitService.revertCommit(repo, commit.sha);
            break;
          case 'reset':
            final mode = await showDialog<String>(
              context: context,
              builder: (ctx) {
                String selectedMode = 'mixed';
                return StatefulBuilder(
                  builder: (ctx, setDialogState) {
                    return AlertDialog(
                      title: const Text('Reset to Commit'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Reset current branch HEAD to ${commit.shortSha}?\n'),
                          RadioListTile<String>(
                            title: const Text('Soft (--soft)'),
                            subtitle: const Text('Keep changes staged for commit'),
                            value: 'soft',
                            groupValue: selectedMode,
                            onChanged: (val) => setDialogState(() => selectedMode = val!),
                          ),
                          RadioListTile<String>(
                            title: const Text('Mixed (--mixed)'),
                            subtitle: const Text('Keep changes unstaged'),
                            value: 'mixed',
                            groupValue: selectedMode,
                            onChanged: (val) => setDialogState(() => selectedMode = val!),
                          ),
                          RadioListTile<String>(
                            title: const Text('Hard (--hard)'),
                            subtitle: const Text('Discard all changes (WARNING: destructive)'),
                            value: 'hard',
                            groupValue: selectedMode,
                            onChanged: (val) => setDialogState(() => selectedMode = val!),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(null),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(selectedMode),
                          child: const Text('Reset', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    );
                  },
                );
              },
            );
            if (mode == null) return;
            if (mode == 'hard') {
              final confirmHard = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Hard Reset'),
                  content: const Text('Warning: A hard reset will permanently discard all unstaged and staged changes in your working directory. This action cannot be undone.\n\nAre you sure you want to proceed?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Hard Reset', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmHard != true) return;
            }
            await gitService.reset(repo, commit.sha, mode: mode);
            break;
          case 'branch':
            final textController = TextEditingController();
            final branchName = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Create Branch Here'),
                content: TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: 'Branch name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
            if (branchName != null && branchName.isNotEmpty) {
              await gitService.createBranch(repo, branchName, startPoint: commit.sha);
            }
            break;
          case 'tag':
            final nameController = TextEditingController();
            final messageController = TextEditingController();
            final tagInfo = await showDialog<Map<String, String>>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Create Tag Here'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tag name (required)'),
                    ),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(labelText: 'Message (optional)'),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop({
                      'name': nameController.text.trim(),
                      'message': messageController.text.trim(),
                    }),
                    child: const Text('Create'),
                  ),
                ],
              ),
            );
            if (tagInfo != null && tagInfo['name']!.isNotEmpty) {
              await gitService.createTag(
                repo,
                tagInfo['name']!,
                target: commit.sha,
                message: tagInfo['message']!.isNotEmpty ? tagInfo['message'] : null,
              );
            }
            break;
          case 'copy':
            await Clipboard.setData(ClipboardData(text: commit.sha));
            break;
        }

        if (mounted) {
          _refreshRepository(context, repo);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Operation failed: $e')),
          );
        }
      }
    });
  }

  void _refreshRepository(BuildContext context, GitRepo repo) {
    final commitGraphState = context.read<CommitGraphBloc>().state;
    context.read<CommitGraphBloc>().add(LoadCommitHistoryEvent(repo, branch: commitGraphState.branchFilter));
    context.read<SidebarBloc>().add(LoadSidebarEvent(repo));
    context.read<RepositoryBloc>().add(const RefreshRepositoryEvent());
    context.read<StagingBloc>().add(LoadWorkingCopyEvent(repo));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommitGraphBloc, CommitGraphState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            // Toolbar search / filter
            _buildSearchToolbar(context, state),

            // Header row
            _buildTableHeader(),

            // Commit List
            Expanded(
              child: state.visibleCommits.isEmpty
                  ? const Center(
                      child: Text(
                        'No commits matching this filter.',
                        style: TextStyle(color: FurcateTheme.darkTextSecondary),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            // Scrollable CustomPaint in background (synchronized scroll)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 120,
                              child: IgnorePointer(
                                child: ClipRect(
                                  child: SingleChildScrollView(
                                    controller: _graphScrollController,
                                    physics: const NeverScrollableScrollPhysics(), // Handled by ListView
                                    child: CustomPaint(
                                      size: Size(120, state.visibleCommits.length * 28.0),
                                      painter: CommitGraphPainter(
                                        commits: state.visibleCommits,
                                        rowHeight: 28.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // ListView for Text columns
                            NotificationListener<ScrollNotification>(
                              onNotification: (scrollNotification) {
                                if (_graphScrollController.hasClients && _listScrollController.hasClients) {
                                  _graphScrollController.jumpTo(_listScrollController.offset);
                                }
                                return false;
                              },
                              child: ListView.builder(
                                controller: _listScrollController,
                                itemCount: state.visibleCommits.length,
                                itemExtent: 28.0,
                                itemBuilder: (context, index) {
                                  final gc = state.visibleCommits[index];
                                  final isSelected = state.selectedCommit?.sha == gc.commit.sha;

                                  return GestureDetector(
                                    onTap: () {
                                      context.read<CommitGraphBloc>().add(SelectCommitEvent(gc.commit));
                                    },
                                    onSecondaryTapDown: (details) {
                                      _showCommitContextMenu(context, details, gc.commit);
                                    },
                                    child: Container(
                                      color: isSelected
                                          ? FurcateTheme.darkSelection
                                          : (index % 2 == 0 ? Colors.transparent : FurcateTheme.darkBgSecondary.withOpacity(0.3)),
                                      child: Row(
                                        children: [
                                          // Padding placeholder for the graph (width matching painter layout)
                                          const SizedBox(width: 100),

                                          // Commit description + Branch badges
                                          Expanded(
                                            child: Row(
                                              children: [
                                                // Refs/Badges
                                                if (gc.commit.refs.isNotEmpty) ...[
                                                  ...gc.commit.refs.map((ref) => _buildRefBadge(ref)),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    gc.commit.summary,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isSelected ? FurcateTheme.darkTextEmphasis : FurcateTheme.darkTextPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Author
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              gc.commit.author.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextSecondary),
                                            ),
                                          ),

                                          // Date
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              DateFormat('yyyy-MM-dd').format(gc.commit.dateTime),
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextSecondary),
                                            ),
                                          ),

                                          // SHA
                                          SizedBox(
                                            width: 70,
                                            child: Text(
                                              gc.commit.shortSha,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'Courier',
                                                color: FurcateTheme.darkTextSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchToolbar(BuildContext context, CommitGraphState state) {
    return Container(
      height: 36,
      color: FurcateTheme.darkBgToolbar,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: FurcateTheme.darkTextSecondary),
          const SizedBox(width: 8),
          const Text(
            'History',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextEmphasis),
          ),
          if (state.branchFilter != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: FurcateTheme.darkSelection,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Text(
                    state.branchFilter!.split('/').last,
                    style: const TextStyle(fontSize: 11, color: FurcateTheme.darkTextEmphasis),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),

          // Search commit input
          Container(
            width: 180,
            height: 24,
            decoration: BoxDecoration(
              color: FurcateTheme.darkBgSecondary,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: FurcateTheme.darkBorder),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                context.read<CommitGraphBloc>().add(SearchGraphCommitsEvent(val));
              },
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: 'Search commits...',
                hintStyle: const TextStyle(color: FurcateTheme.darkTextSecondary, fontSize: 11),
                prefixIcon: const Icon(Icons.search, size: 12, color: FurcateTheme.darkTextSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          context.read<CommitGraphBloc>().add(const SearchGraphCommitsEvent(''));
                        },
                        child: const Icon(Icons.clear, size: 12, color: FurcateTheme.darkTextSecondary),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.only(bottom: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 24,
      decoration: const BoxDecoration(
        color: FurcateTheme.darkBgTitlebar,
        border: Border(bottom: BorderSide(color: FurcateTheme.darkBorder, width: 1)),
      ),
      child: const Row(
        children: [
          SizedBox(width: 100, child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text('Graph', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary)),
          )),
          Expanded(child: Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary))),
          SizedBox(width: 140, child: Text('Author', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary))),
          SizedBox(width: 100, child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary))),
          SizedBox(width: 70, child: Text('SHA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary))),
        ],
      ),
    );
  }

  Widget _buildRefBadge(RefEntity ref) {
    final isTag = ref.type == 'tag';
    final isRemote = ref.type == 'remote';

    final bgColor = isTag
        ? Colors.grey[800]!
        : (isRemote ? const Color(0xFF3F3F46) : FurcateTheme.darkAccent.withOpacity(0.85));

    final textColor = isTag ? Colors.yellow[300]! : FurcateTheme.darkTextEmphasis;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        ref.name.split('/').last,
        style: TextStyle(fontSize: 10, color: textColor, fontWeight: FontWeight.bold),
      ),
    );
  }
}
