import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';
import 'core/locator.dart';
import 'core/theme.dart';
import 'git_engine/git_service.dart';
import 'features/repository_manager/repository_manager_bloc.dart';
import 'features/repository_manager/welcome_screen.dart';
import 'features/repository/workspace.dart';
import 'features/window_chrome/window_chrome.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
  }

  setupLocator();

  runApp(const FurcateApp());

  const gitHash = String.fromEnvironment('GIT_HASH', defaultValue: 'local');
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1280, 720),
        center: true,
        title: 'Furcate — Git Client ($gitHash)',
      ),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
}

class FurcateApp extends StatelessWidget {
  const FurcateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RepositoryManagerBloc>(
      create: (context) => RepositoryManagerBloc(locator<GitService>())..add(const LoadRecentReposEvent()),
      child: MaterialApp(
        title: 'Furcate',
        theme: FurcateTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const AppContentGate(),
      ),
    );
  }
}

class AppContentGate extends StatelessWidget {
  const AppContentGate({super.key});

  @override
  Widget build(BuildContext context) {
    return WindowChrome(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 580) {
            return _buildUnfoldPrompt(context);
          }

          return BlocBuilder<RepositoryManagerBloc, RepositoryManagerState>(
            builder: (context, state) {
              final activeTab = state.activeTab;
              if (activeTab == null) {
                return const WelcomeScreen();
              }

              // Render active repo workspace
              return MainWorkspace(
                key: ValueKey(activeTab.id),
                repo: GitRepo(path: activeTab.path, name: activeTab.name),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUnfoldPrompt(BuildContext context) {
    return Scaffold(
      backgroundColor: FurcateTheme.darkBgPrimary,
      body: Container(
        padding: const EdgeInsets.all(32),
        color: FurcateTheme.darkBgPrimary,
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.phonelink_setup,
                  size: 64,
                  color: FurcateTheme.darkAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unfold to Access Workspace',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: FurcateTheme.darkTextEmphasis,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Furcate Git Client requires all screen real estate to show commit graphs, staging panels, and side-by-side diff viewers.\n\nPlease unfold your device or rotate to landscape to access your workspace.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: FurcateTheme.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FurcateTheme.darkBgToolbar,
                    foregroundColor: FurcateTheme.darkTextPrimary,
                    side: const BorderSide(color: FurcateTheme.darkBorder, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () {
                    // Quick feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unfold your folding phone to begin.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'Rotate or Unfold',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
