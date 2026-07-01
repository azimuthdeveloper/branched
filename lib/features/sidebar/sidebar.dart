import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../core/locator.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import '../repository_manager/repository_manager_bloc.dart';
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
