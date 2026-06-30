import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';
import 'sidebar_bloc.dart';

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key});

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  final Map<String, bool> _isExpanded = {
    'Branches': true,
    'Remotes': true,
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
}
