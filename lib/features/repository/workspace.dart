import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/locator.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import '../commit_graph/commit_graph_bloc.dart';
import '../commit_graph/commit_graph.dart';
import '../diff_viewer/diff_viewer_bloc.dart';
import '../diff_viewer/diff_panel.dart';
import '../sidebar/sidebar_bloc.dart';
import '../sidebar/sidebar.dart';
import '../staging/staging_bloc.dart';
import '../staging/staging_panel.dart';
import 'repository_bloc.dart';
import 'toolbar.dart';

class MainWorkspace extends StatelessWidget {
  final GitRepo repo;

  const MainWorkspace({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    // Provide all repository-scoped blocs to the subtree
    return MultiBlocProvider(
      providers: [
        BlocProvider<RepositoryBloc>(
          create: (context) => RepositoryBloc(locator<GitService>())..add(LoadRepositoryDetailsEvent(repo.path)),
        ),
        BlocProvider<SidebarBloc>(
          create: (context) => SidebarBloc(locator<GitService>())..add(LoadSidebarEvent(repo)),
        ),
        BlocProvider<CommitGraphBloc>(
          create: (context) => CommitGraphBloc(locator<GitService>())..add(LoadCommitHistoryEvent(repo)),
        ),
        BlocProvider<StagingBloc>(
          create: (context) => StagingBloc(locator<GitService>())..add(LoadWorkingCopyEvent(repo)),
        ),
        BlocProvider<DiffViewerBloc>(
          create: (context) => DiffViewerBloc(locator<GitService>()),
        ),
      ],
      child: BlocListener<SidebarBloc, SidebarState>(
        listener: (context, state) {
          // Whenever selected branch changes, load appropriate history
          if (state.selectedItem.type == SidebarItemType.branch ||
              state.selectedItem.type == SidebarItemType.remoteBranch) {
            context.read<CommitGraphBloc>().add(
                  LoadCommitHistoryEvent(repo, branch: state.selectedItem.refName),
                );
          } else if (state.selectedItem.type == SidebarItemType.tag) {
            context.read<CommitGraphBloc>().add(
                  LoadCommitHistoryEvent(repo), // Tag selections show all history, then we can jump to it
                );
          }
        },
        child: Container(
          color: FurcateTheme.darkBgPrimary,
          child: Column(
            children: [
              // Toolbar
              ToolbarWidget(repo: repo),

              // Layout below Toolbar
              Expanded(
                child: Row(
                  children: [
                    // Sidebar
                    const SidebarWidget(),

                    const VerticalDivider(color: FurcateTheme.darkBorder, width: 1),

                    // Main Content depending on Sidebar Selection
                    Expanded(
                      child: BlocBuilder<SidebarBloc, SidebarState>(
                        builder: (context, sidebarState) {
                          if (sidebarState.selectedItem.type == SidebarItemType.changes) {
                            return StagingPanel(repo: repo);
                          } else {
                            return _buildHistoryAndCommitDetailView(context, repo);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryAndCommitDetailView(BuildContext context, GitRepo repo) {
    return Column(
      children: [
        // Commit History Graph Panel
        const Expanded(
          flex: 6,
          child: CommitGraphWidget(),
        ),

        const Divider(color: FurcateTheme.darkBorder, height: 1),

        // Commit Details Bottom Panel
        Expanded(
          flex: 4,
          child: BlocBuilder<CommitGraphBloc, CommitGraphState>(
            builder: (context, state) {
              final commit = state.selectedCommit;
              if (commit == null) {
                return const Center(
                  child: Text(
                    'No commit selected.',
                    style: TextStyle(color: FurcateTheme.darkTextSecondary),
                  ),
                );
              }

              return _CommitDetailPanel(repo: repo, commit: commit);
            },
          ),
        ),
      ],
    );
  }
}

class _CommitDetailPanel extends StatefulWidget {
  final GitRepo repo;
  final CommitEntity commit;

  const _CommitDetailPanel({required this.repo, required this.commit});

  @override
  State<_CommitDetailPanel> createState() => _CommitDetailPanelState();
}

class _CommitDetailPanelState extends State<_CommitDetailPanel> {
  List<FileDiffEntity> _changedFiles = [];
  String? _selectedFilePath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCommitDetails();
  }

  @override
  void didUpdateWidget(_CommitDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commit.sha != widget.commit.sha) {
      _loadCommitDetails();
    }
  }

  void _loadCommitDetails() async {
    setState(() {
      _isLoading = true;
      _selectedFilePath = null;
    });

    try {
      final diffs = await locator<GitService>().getCommitDiff(widget.repo, widget.commit.sha);
      setState(() {
        _changedFiles = diffs;
        _isLoading = false;
        if (diffs.isNotEmpty) {
          _selectedFilePath = diffs.first.path;
          context.read<DiffViewerBloc>().add(
                LoadFileDiffEvent(repo: widget.repo, path: diffs.first.path, commitSha: widget.commit.sha),
              );
        }
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // Left Column: Modified files list
        Container(
          width: 250,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: FurcateTheme.darkBorder, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 24,
                color: FurcateTheme.darkBgTitlebar,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Files Changed (${_changedFiles.length})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextSecondary),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _changedFiles.length,
                  itemBuilder: (context, index) {
                    final file = _changedFiles[index];
                    final isSelected = _selectedFilePath == file.path;

                    Color statusColor = Colors.orange;
                    String statusChar = 'M';
                    if (file.status == FileChangeStatus.added) {
                      statusColor = FurcateTheme.diffAddText;
                      statusChar = 'A';
                    } else if (file.status == FileChangeStatus.deleted) {
                      statusColor = FurcateTheme.diffDelText;
                      statusChar = 'D';
                    }

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilePath = file.path;
                        });
                        context.read<DiffViewerBloc>().add(
                              LoadFileDiffEvent(
                                repo: widget.repo,
                                path: file.path,
                                commitSha: widget.commit.sha,
                              ),
                            );
                      },
                      child: Container(
                        height: 24,
                        color: isSelected ? FurcateTheme.darkSelection : Colors.transparent,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                statusChar,
                                style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.path,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: FurcateTheme.darkTextPrimary),
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
          ),
        ),

        // Right Column: Diff Preview
        Expanded(
          child: _selectedFilePath == null
              ? const Center(
                  child: Text(
                    'No file selected.',
                    style: TextStyle(color: FurcateTheme.darkTextSecondary),
                  ),
                )
              : DiffPanel(repo: widget.repo),
        ),
      ],
    );
  }
}
