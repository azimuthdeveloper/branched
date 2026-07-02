import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:branched/main.dart';
import 'package:branched/core/locator.dart';
import 'package:branched/git_engine/git_service.dart';
import 'package:branched/git_engine/git_service_impl.dart';
import 'package:branched/features/sidebar/sidebar.dart';
import 'package:branched/features/sidebar/sidebar_bloc.dart';
import 'package:branched/features/staging/staging_bloc.dart';
import 'package:branched/features/staging/staging_panel.dart';
import 'package:branched/core/file_picker_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final testRepoPath = '/root/branched/test_resources/real_git_test_repo';

  Future<void> runGit(List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: testRepoPath);
    if (result.exitCode != 0) {
      throw Exception('Git command failed: git ${args.join(' ')}\nStderr: ${result.stderr}');
    }
  }

  setUpAll(() async {
    // 1. Register RealGitService instead of MockGitService
    locator.registerLazySingleton<GitService>(() => RealGitService());
    locator.registerLazySingleton<FilePickerService>(() => TestFilePickerService(testRepoPath));

    // 2. Dynamically set up a real Git repository under testRepoPath
    final dir = Directory(testRepoPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    await runGit(['init']);
    await runGit(['config', 'user.name', 'Integration Tester']);
    await runGit(['config', 'user.email', 'tester@example.com']);
    await runGit(['config', 'commit.gpgsign', 'false']);

    // Create initial commit on main
    final readme = File('$testRepoPath/Readme.md');
    readme.writeAsStringSync('# Branched Test Repo\nInitial content\n');
    await runGit(['add', 'Readme.md']);
    await runGit(['commit', '-m', 'Initial commit']);

    await runGit(['branch', '-M', 'main']);

    // Create a local branch feature/auth
    await runGit(['branch', 'feature/auth']);

    // Create a tag
    await runGit(['tag', 'v1.0.0']);

    // Create a submodule locally using a second scratch repo
    final subRepoPath = '/root/branched/test_resources/real_git_submodule_repo';
    final subDir = Directory(subRepoPath);
    if (subDir.existsSync()) {
      subDir.deleteSync(recursive: true);
    }
    subDir.createSync(recursive: true);
    await Process.run('git', ['init'], workingDirectory: subRepoPath);
    await Process.run('git', ['config', 'user.name', 'Sub Tester'], workingDirectory: subRepoPath);
    await Process.run('git', ['config', 'user.email', 'sub@example.com'], workingDirectory: subRepoPath);
    File('$subRepoPath/sub_readme.md').writeAsStringSync('Submodule content');
    await Process.run('git', ['add', 'sub_readme.md'], workingDirectory: subRepoPath);
    await Process.run('git', ['commit', '-m', 'Submodule init commit'], workingDirectory: subRepoPath);

    // Add submodule to parent repo using its local path with protocol.file.allow=always
    await runGit(['-c', 'protocol.file.allow=always', 'submodule', 'add', subRepoPath, 'plugins/my_submodule']);
    await runGit(['commit', '-m', 'Add local submodule']);
  });

  tearDownAll(() {
    // Cleanup generated repositories after testing
    final dir = Directory(testRepoPath);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    final subDir = Directory('/root/branched/test_resources/real_git_submodule_repo');
    if (subDir.existsSync()) {
      subDir.deleteSync(recursive: true);
    }
  });

  testWidgets('Real Git Integration Test - Full Lifecycle, Staging, Submodules & Context Menus', (WidgetTester tester) async {
    final boundaryKey = GlobalKey();

    Future<void> capture(String name) async {
      await tester.pump();
      final RenderRepaintBoundary boundary =
          boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final file = File(
          '/root/.gemini/antigravity-cli/brain/0053cb8d-118d-4863-9be5-8c4549886f5f/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(pngBytes);
    }

    // 1. Launch the application inside a RepaintBoundary
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: const FurcateApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Welcome screen
    expect(find.text('Furcate'), findsOneWidget);
    await capture('real_01_welcome_screen');

    // 2. Open the real Git repository
    await tester.tap(find.text('Open Repository'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify Workspace renders and the active branch is 'main'
    expect(find.text('main'), findsWidgets);
    expect(find.text('Changes'), findsWidgets);
    await capture('real_02_workspace_loaded');

    // 3. Submodule list check
    // Ensure the Submodules header appears, and tap to expand
    expect(find.text('SUBMODULES'), findsOneWidget);
    await tester.tap(find.text('SUBMODULES'));
    await tester.pumpAndSettle();
    expect(find.text('plugins/my_submodule'), findsOneWidget);
    await capture('real_03_submodules_loaded');

    // 4. Branch Checkout Flow via Sidebar
    final sidebarAuthFinder = find.descendant(
      of: find.byType(SidebarWidget),
      matching: find.text('feature/auth'),
    );
    expect(sidebarAuthFinder, findsOneWidget);
    await tester.tap(sidebarAuthFinder);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await capture('real_04_branch_checked_out');

    // 5. Switch back to Changes and stage a file
    final sidebarChangesFinder = find.descendant(
      of: find.byType(SidebarWidget),
      matching: find.text('Changes'),
    );
    await tester.tap(sidebarChangesFinder);
    await tester.pumpAndSettle();

    // Make an unstaged change in the repository
    final newFile = File('$testRepoPath/new_test_file.txt');
    newFile.writeAsStringSync('Hello, this is a test from integration environment.');

    // Dispatch load working copy event to refresh staging panel
    final BuildContext context = tester.element(find.byType(SidebarWidget));
    context.read<StagingBloc>().add(LoadWorkingCopyEvent(GitRepo(path: testRepoPath, name: 'real_git_test_repo')));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify the unstaged file list is loaded
    expect(find.text('Unstaged Changes (1)'), findsOneWidget);
    expect(find.text('new_test_file.txt'), findsOneWidget);
    await capture('real_05_unstaged_change_visible');

    // Click the Add/Stage button (the '+' icon button next to the file row)
    final stageButtonFinder = find.descendant(
      of: find.byType(StagingPanel),
      matching: find.byIcon(Icons.add),
    );
    expect(stageButtonFinder, findsOneWidget);
    await tester.tap(stageButtonFinder);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify the file was staged
    expect(find.text('Staged Changes (1)'), findsOneWidget);
    expect(find.text('Unstaged Changes (0)'), findsOneWidget);
    await capture('real_06_staged_change_visible');

    // 6. Enter commit message and commit
    final summaryField = find.byWidgetPredicate((w) => w is TextField && w.decoration?.hintText == 'Commit summary (required)');
    expect(summaryField, findsOneWidget);
    await tester.enterText(summaryField, 'feat: integration test real commit');
    await tester.pumpAndSettle();
    await capture('real_07_commit_msg_entered');

    final stagingBloc = context.read<StagingBloc>();
    print('DEBUG: Before commit - staged: ${stagingBloc.state.stagedFiles.length}');
    await tester.tap(find.text('Commit'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    print('DEBUG: After commit - staged: ${stagingBloc.state.stagedFiles.length}, error: ${stagingBloc.state.error}, isCommitting: ${stagingBloc.state.isCommitting}');

    // Verify changes are cleared
    expect(find.text('Staged Changes (0)'), findsOneWidget);
    await capture('real_08_commit_complete');
  });
}

class TestFilePickerService implements FilePickerService {
  final String path;
  TestFilePickerService(this.path);

  @override
  Future<String?> getDirectoryPath({String? dialogTitle}) async {
    return path;
  }
}
