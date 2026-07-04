import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/theme.dart';
import '../../core/locator.dart';
import '../../core/file_picker_service.dart';
import 'repository_manager_bloc.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<RepositoryManagerBloc, RepositoryManagerState>(
      listenWhen: (previous, current) => current.error != null && current.error != previous.error,
      listener: (context, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.red[900],
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: FurcateTheme.darkBgPrimary,
        body: Center(
        child: Container(
          width: 640,
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo/Header
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.call_split, size: 48, color: FurcateTheme.darkAccent),
                  SizedBox(width: 16),
                  Text(
                    'Furcate',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: FurcateTheme.darkTextEmphasis,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'A fast and powerful Git client clone built with Flutter.',
                  style: TextStyle(fontSize: 13, color: FurcateTheme.darkTextSecondary),
                ),
              ),
              const SizedBox(height: 48),

              // Action Cards Row
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.folder_open,
                      title: 'Open Repository',
                      subtitle: 'Open an existing local Git repository',
                      onTap: () => _openRepository(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.cloud_download,
                      title: 'Clone Repository',
                      subtitle: 'Clone a remote repository to your disk',
                      onTap: () => _showCloneRepoDialog(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildActionCard(
                context,
                icon: Icons.create_new_folder,
                title: 'Create New Repository',
                subtitle: 'Initialize a brand new Git repository',
                onTap: () => _initRepository(context),
              ),
              const SizedBox(height: 40),

              // Recent Repos Header
              const Text(
                'RECENT REPOSITORIES',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: FurcateTheme.darkTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Recent Repos List
              Expanded(
                child: BlocBuilder<RepositoryManagerBloc, RepositoryManagerState>(
                  builder: (context, state) {
                    if (state.recentRepos.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FurcateTheme.darkBgSecondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: FurcateTheme.darkBorder),
                        ),
                        child: const Center(
                          child: Text(
                            'No recent repositories.',
                            style: TextStyle(fontSize: 12, color: FurcateTheme.darkTextSecondary),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: state.recentRepos.length,
                      itemBuilder: (context, index) {
                        final path = state.recentRepos[index];
                        final name = path.split('/').last;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: FurcateTheme.darkBgSecondary,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: FurcateTheme.darkBorder),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder, color: FurcateTheme.darkTextSecondary, size: 16),
                            title: Text(
                              name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FurcateTheme.darkTextPrimary),
                            ),
                            subtitle: Text(
                              path,
                              style: const TextStyle(fontSize: 10, color: FurcateTheme.darkTextSecondary),
                            ),
                            trailing: const Icon(Icons.star_border, size: 16, color: FurcateTheme.darkTextSecondary),
                            onTap: () {
                              context.read<RepositoryManagerBloc>().add(OpenRepositoryEvent(path));
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FurcateTheme.darkBgSecondary,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: FurcateTheme.darkBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: FurcateTheme.darkAccent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: FurcateTheme.darkTextEmphasis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: FurcateTheme.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRepository(BuildContext context) async {
    final selectedDir = await locator<FilePickerService>().getDirectoryPath(
      dialogTitle: 'Open Git Repository',
    );
    if (selectedDir == null) return; // User cancelled
    if (!context.mounted) return;
    context.read<RepositoryManagerBloc>().add(OpenRepositoryEvent(selectedDir));
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

  void _initRepository(BuildContext context) async {
    final selectedDir = await locator<FilePickerService>().getDirectoryPath(
      dialogTitle: 'Select Directory to Initialize',
    );
    if (selectedDir == null) return; // User cancelled
    if (!context.mounted) return;
    context.read<RepositoryManagerBloc>().add(InitRepositoryEvent(selectedDir));
  }
}
