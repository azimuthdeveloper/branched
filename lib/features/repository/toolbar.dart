import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme.dart';
import '../../git_engine/git_service.dart';
import '../../core/locator.dart';
import '../commit_graph/commit_graph_bloc.dart';
import '../sidebar/sidebar_bloc.dart';
import 'repository_bloc.dart';

class ToolbarWidget extends StatefulWidget {
  final GitRepo repo;

  const ToolbarWidget({super.key, required this.repo});

  @override
  State<ToolbarWidget> createState() => _ToolbarWidgetState();
}

class _ToolbarWidgetState extends State<ToolbarWidget> {
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncPhase = '';

  void _triggerSync(String action, Future<void> Function() syncCall) async {
    setState(() {
      _isSyncing = true;
      _syncProgress = 0.0;
      _syncPhase = '$action...';
    });

    for (var i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      setState(() {
        _syncProgress = i / 5;
      });
    }

    try {
      await syncCall();
    } catch (_) {}

    setState(() {
      _isSyncing = false;
    });

    if (mounted) {
      context.read<RepositoryBloc>().add(const RefreshRepositoryEvent());
      context.read<SidebarBloc>().add(LoadSidebarEvent(widget.repo));
      context.read<CommitGraphBloc>().add(LoadCommitHistoryEvent(widget.repo));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: const BoxDecoration(
        color: FurcateTheme.darkBgToolbar,
        border: Border(bottom: BorderSide(color: FurcateTheme.darkBorder, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          // Navigation arrows
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 16, color: FurcateTheme.darkTextSecondary),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 16, color: FurcateTheme.darkTextSecondary),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          _buildDivider(),

          // Fetch Button
          _buildToolbarButton(
            icon: Icons.download,
            label: 'Fetch',
            onPressed: _isSyncing
                ? null
                : () => _triggerSync('Fetching', () => locator<GitService>().fetch(widget.repo)),
          ),
          const SizedBox(width: 4),

          // Pull Button
          _buildToolbarButton(
            icon: Icons.south,
            label: 'Pull',
            onPressed: _isSyncing
                ? null
                : () => _triggerSync('Pulling', () => locator<GitService>().pull(widget.repo)),
          ),
          const SizedBox(width: 4),

          // Push Button
          _buildToolbarButton(
            icon: Icons.north,
            label: 'Push',
            onPressed: _isSyncing
                ? null
                : () => _triggerSync('Pushing', () => locator<GitService>().push(widget.repo)),
          ),
          const SizedBox(width: 16),
          _buildDivider(),

          // Stash Pop Button
          _buildToolbarButton(
            icon: Icons.unarchive_outlined,
            label: 'Stash Pop',
            onPressed: _isSyncing
                ? null
                : () => _triggerSync('Popping Stash', () => locator<GitService>().popStash(widget.repo, 0)),
          ),
          const SizedBox(width: 16),
          _buildDivider(),

          // Progress Overlay in Toolbar
          if (_isSyncing) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Text(
                    _syncPhase,
                    style: const TextStyle(fontSize: 11, color: FurcateTheme.darkTextSecondary),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    height: 4,
                    child: LinearProgressIndicator(
                      value: _syncProgress,
                      backgroundColor: FurcateTheme.darkBorder,
                      valueColor: const AlwaysStoppedAnimation(FurcateTheme.darkAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 18,
      color: FurcateTheme.darkBorder,
    );
  }

  Widget _buildToolbarButton({required IconData icon, required String label, VoidCallback? onPressed}) {
    final disabled = onPressed == null;
    return TextButton.styleFrom(
      foregroundColor: FurcateTheme.darkTextPrimary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
    ).copyWith(
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.hovered)) {
          return FurcateTheme.darkBgSecondary;
        }
        return Colors.transparent;
      }),
    ).build(
      context,
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, size: 14, color: disabled ? FurcateTheme.darkTextSecondary : FurcateTheme.darkTextPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: disabled ? FurcateTheme.darkTextSecondary : FurcateTheme.darkTextPrimary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

extension on ButtonStyle {
  Widget build(BuildContext context, {required VoidCallback? onPressed, required Widget child}) {
    return TextButton(
      style: this,
      onPressed: onPressed,
      child: child,
    );
  }
}
