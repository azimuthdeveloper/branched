import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';
import '../../git_engine/git_service.dart';
import 'diff_viewer_bloc.dart';

class DiffPanel extends StatelessWidget {
  final GitRepo repo;

  const DiffPanel({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiffViewerBloc, DiffViewerState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final diff = state.diff;
        if (diff == null) {
          return const Center(
            child: Text(
              'No diff loaded.',
              style: TextStyle(color: FurcateTheme.darkTextSecondary),
            ),
          );
        }

        return Container(
          color: FurcateTheme.darkBgPrimary,
          child: Column(
            children: [
              // Toolbar
              _buildDiffToolbar(context, state, diff),

              // Code List
              Expanded(
                child: ListView.builder(
                  itemCount: diff.hunks.fold<int>(0, (sum, hunk) => sum + 1 + hunk.lines.length),
                  itemBuilder: (context, index) {
                    // Flatten hunks and lines into a single list of index entries
                    var curIndex = 0;
                    for (final hunk in diff.hunks) {
                      if (curIndex == index) {
                        return _buildHunkHeaderRow(hunk);
                      }
                      curIndex++;

                      for (final line in hunk.lines) {
                        if (curIndex == index) {
                          return _buildLineRow(line);
                        }
                        curIndex++;
                      }
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiffToolbar(BuildContext context, DiffViewerState state, FileDiffEntity diff) {
    return Container(
      height: 32,
      color: FurcateTheme.darkBgToolbar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.description, size: 14, color: FurcateTheme.darkTextSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              diff.path,
              style: const TextStyle(fontSize: 11, fontFamily: 'Courier', color: FurcateTheme.darkTextPrimary),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${diff.addedLines} −${diff.deletedLines}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: FurcateTheme.diffAddText),
          ),
          const SizedBox(width: 12),
          // Toggle UI mode placeholder
          Row(
            children: [
              _buildToggleBtn(context, state, DiffMode.unified, 'Unified'),
              _buildToggleBtn(context, state, DiffMode.split, 'Split'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(BuildContext context, DiffViewerState state, DiffMode mode, String label) {
    final active = state.mode == mode;
    return GestureDetector(
      onTap: () {
        context.read<DiffViewerBloc>().add(ToggleDiffModeEvent(mode));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? FurcateTheme.darkSelection : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, color: active ? FurcateTheme.darkTextEmphasis : FurcateTheme.darkTextSecondary),
        ),
      ),
    );
  }

  Widget _buildHunkHeaderRow(DiffHunkEntity hunk) {
    return Container(
      color: FurcateTheme.diffHunkBg.withOpacity(0.4),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.unfold_more, size: 10, color: FurcateTheme.darkTextSecondary),
              ],
            ),
          ),
          Expanded(
            child: Text(
              hunk.header,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Courier',
                color: FurcateTheme.darkTextSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineRow(DiffLineEntity line) {
    Color? rowBg;
    Color numColor = FurcateTheme.darkTextSecondary;
    Color contentColor = FurcateTheme.darkTextPrimary;

    if (line.origin == DiffLineOrigin.addition) {
      rowBg = FurcateTheme.diffAddBg.withOpacity(0.35);
      numColor = FurcateTheme.diffAddText.withOpacity(0.7);
      contentColor = FurcateTheme.diffAddText;
    } else if (line.origin == DiffLineOrigin.deletion) {
      rowBg = FurcateTheme.diffDelBg.withOpacity(0.35);
      numColor = FurcateTheme.diffDelText.withOpacity(0.7);
      contentColor = FurcateTheme.diffDelText;
    }

    return Container(
      color: rowBg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gutter columns
          Container(
            width: 40,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              line.oldLineNumber?.toString() ?? '',
              style: TextStyle(fontSize: 11, fontFamily: 'Courier', color: numColor),
            ),
          ),
          Container(
            width: 40,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              line.newLineNumber?.toString() ?? '',
              style: TextStyle(fontSize: 11, fontFamily: 'Courier', color: numColor),
            ),
          ),

          // Divider
          Container(width: 1, height: 20, color: FurcateTheme.darkBorder),

          // Code line content
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                line.content,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Courier',
                  color: contentColor,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
