import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';
import 'commit_graph_bloc.dart';
import 'commit_graph_painter.dart';

class CommitGraphWidget extends StatefulWidget {
  const CommitGraphWidget({super.key});

  @override
  State<CommitGraphWidget> createState() => _CommitGraphWidgetState();
}

class _CommitGraphWidgetState extends State<CommitGraphWidget> {
  final _searchController = TextEditingController();

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
                            // Custom Painter for Graph in background
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 120,
                              child: IgnorePointer(
                                child: CustomPaint(
                                  size: Size(120, state.visibleCommits.length * 28.0),
                                  painter: CommitGraphPainter(
                                    commits: state.visibleCommits,
                                    rowHeight: 28.0,
                                  ),
                                ),
                              ),
                            ),

                            // ListView for Text columns
                            ListView.builder(
                              itemCount: state.visibleCommits.length,
                              itemExtent: 28.0,
                              itemBuilder: (context, index) {
                                final gc = state.visibleCommits[index];
                                final isSelected = state.selectedCommit?.sha == gc.commit.sha;

                                return GestureDetector(
                                  onTap: () {
                                    context.read<CommitGraphBloc>().add(SelectCommitEvent(gc.commit));
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
