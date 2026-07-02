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
  
  // Must initialize window_manager since it is compiled in and hides the window by default
  await windowManager.ensureInitialized();

  setupLocator();

  runApp(const FurcateApp());

  const gitHash = String.fromEnvironment('GIT_HASH', defaultValue: 'local');
  // Show window once it is fully ready
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
      child: BlocBuilder<RepositoryManagerBloc, RepositoryManagerState>(
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
      ),
    );
  }
}
