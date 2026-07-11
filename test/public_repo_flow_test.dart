import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:branched/main.dart';
import 'package:branched/core/locator.dart';
import 'package:branched/git_engine/git_service.dart';
import 'package:branched/git_engine/git_service_impl.dart';
import 'package:branched/features/sidebar/sidebar.dart';
import 'package:branched/features/sidebar/sidebar_bloc.dart';
import 'package:branched/features/staging/staging_bloc.dart';
import 'package:branched/features/staging/staging_panel.dart';
import 'package:branched/features/commit_graph/commit_graph_bloc.dart';
import 'package:branched/core/file_picker_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

/// End-to-end widget flow against a real local git repository.
///
/// Clone is exercised through [RealGitService.cloneRepository]; the UI path
/// under test is open → workspace → graph → stage/commit → branch/tag/stash.
void main() {
  late Directory tempDir;
  late String sourceRepoPath;
  late String clonedRepoPath;
  late String defaultBranch;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    tempDir = Directory.systemTemp.createTempSync('branched_integration_local_');
    sourceRepoPath = p.join(tempDir.path, 'source_repo');
    clonedRepoPath = p.join(tempDir.path, 'cloned_repo');

    final gitService = RealGitService();
    final sourceRepo = await gitService.initRepository(sourceRepoPath);

    File(p.join(sourceRepoPath, 'f1.txt')).writeAsStringSync('First file content');
    await gitService.stageFile(sourceRepo, 'f1.txt');
    await gitService.createCommit(sourceRepo, 'feat: first commit on master');
    defaultBranch = (await gitService.getCurrentBranch(sourceRepo)).shortName;

    await gitService.createBranch(sourceRepo, 'branch');
    await gitService.checkoutBranch(sourceRepo, 'branch');
    File(p.join(sourceRepoPath, 'f2.txt')).writeAsStringSync('Second file content');
    await gitService.stageFile(sourceRepo, 'f2.txt');
    await gitService.createCommit(sourceRepo, 'feat: second commit on branch');

    await gitService.checkoutBranch(sourceRepo, defaultBranch);
    File(p.join(sourceRepoPath, 'f3.txt')).writeAsStringSync('Third file content');
    await gitService.stageFile(sourceRepo, 'f3.txt');
    await gitService.createCommit(sourceRepo, 'feat: third commit on master');
    await gitService.merge(sourceRepo, 'branch');

    await gitService.cloneRepository(sourceRepoPath, clonedRepoPath);

    if (locator.isRegistered<GitService>()) {
      await locator.unregister<GitService>();
    }
    locator.registerLazySingleton<GitService>(() => RealGitService());

    if (locator.isRegistered<FilePickerService>()) {
      await locator.unregister<FilePickerService>();
    }
    locator.registerLazySingleton<FilePickerService>(
      () => TestFilePickerService(clonedRepoPath),
    );
  });

  tearDownAll(() {
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('Repo flow - open, graph, stage, commit, branch, tag, stash', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(() async {
      Future<void> waitReal(int ms) async {
        await Future<void>.delayed(Duration(milliseconds: ms));
        await tester.pump();
      }

      await tester.pumpWidget(const FurcateApp());
      await waitReal(300);
      expect(find.text('Furcate'), findsWidgets);

      await tester.tap(find.text('Open Repository'));
      await waitReal(600);

      var workspaceLoaded = false;
      for (var i = 0; i < 40; i++) {
        await waitReal(150);
        if (find.text('Fetch').evaluate().isNotEmpty &&
            find.textContaining('Unstaged Changes').evaluate().isNotEmpty) {
          workspaceLoaded = true;
          break;
        }
      }
      expect(workspaceLoaded, isTrue, reason: 'Workspace failed to load after open.');
      await waitReal(400);

      final context = tester.element(find.byType(SidebarWidget));
      final commitGraphBloc = context.read<CommitGraphBloc>();
      final sidebarBloc = context.read<SidebarBloc>();
      final stagingBloc = context.read<StagingBloc>();
      final gitRepo = GitRepo(path: clonedRepoPath, name: 'cloned_repo');
      final gitService = locator<GitService>();

      for (var i = 0; i < 20; i++) {
        if (commitGraphBloc.state.visibleCommits.isNotEmpty) break;
        await waitReal(100);
      }
      expect(commitGraphBloc.state.visibleCommits, isNotEmpty);

      expect(
        commitGraphBloc.state.visibleCommits
            .any((gc) => gc.commit.summary.contains('first commit on master')),
        isTrue,
      );
      expect(
        commitGraphBloc.state.visibleCommits.any((gc) => gc.commit.isMergeCommit),
        isTrue,
        reason: 'Expected a merge commit in the graph layout data.',
      );

      // Graph layout assigns lanes without crashing on merge topology.
      final layout = commitGraphBloc.state.visibleCommits;
      expect(layout.every((gc) => gc.laneIndex >= 0), isTrue);
      final mergeNode = layout.firstWhere((gc) => gc.commit.isMergeCommit);
      expect(
        mergeNode.connections
            .where((c) =>
                c.type.name.startsWith('branch') ||
                c.type.name.startsWith('merge'))
            .length,
        greaterThanOrEqualTo(1),
      );

      // Select branch → History panel visible.
      final branchRow = find.descendant(
        of: find.byType(SidebarWidget),
        matching: find.text(defaultBranch),
      );
      expect(branchRow, findsWidgets);
      await tester.tap(branchRow.first);
      await waitReal(500);
      expect(find.text('History'), findsOneWidget);

      // --- Stage + commit via UI ---
      File(p.join(clonedRepoPath, 'integration_change.txt'))
          .writeAsStringSync('Integration Test content');
      stagingBloc.add(LoadWorkingCopyEvent(gitRepo));
      await waitReal(800);

      await tester.tap(find.descendant(
        of: find.byType(SidebarWidget),
        matching: find.text('Changes'),
      ));
      await waitReal(400);
      expect(find.text('integration_change.txt'), findsOneWidget);

      final stageButton = find.descendant(
        of: find.byType(StagingPanel),
        matching: find.byIcon(Icons.add),
      );
      expect(stageButton, findsWidgets);
      await tester.tap(stageButton.first);
      await waitReal(800);

      final commitSummaryField = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.hintText == 'Commit summary (required)',
      );
      await tester.enterText(commitSummaryField, 'feat: add integration_change.txt');
      await waitReal(200);
      await tester.tap(find.text('Commit'));
      await waitReal(1500);

      stagingBloc.add(LoadWorkingCopyEvent(gitRepo));
      await waitReal(600);
      expect(stagingBloc.state.stagedFiles, isEmpty);

      commitGraphBloc.add(LoadCommitHistoryEvent(gitRepo));
      await waitReal(800);
      expect(
        commitGraphBloc.state.visibleCommits
            .any((gc) => gc.commit.summary.contains('integration_change')),
        isTrue,
      );

      // --- Branch / tag / stash via engine (UI menus are covered by unit dialogs) ---
      final headSha = commitGraphBloc.state.visibleCommits.first.commit.sha;
      await gitService.createBranch(gitRepo, 'context-branch', startPoint: headSha);
      await gitService.createTag(gitRepo, 'v1.0.9-integration', target: headSha);

      File(p.join(clonedRepoPath, 'stash_change.txt')).writeAsStringSync('stash me');
      // New untracked files require includeUntracked (matches `git stash -u`).
      await gitService.createStash(
        gitRepo,
        message: 'integration-stash',
        includeUntracked: true,
      );

      sidebarBloc.add(LoadSidebarEvent(gitRepo));
      await waitReal(800);

      expect(
        sidebarBloc.state.localBranches.any((b) => b.shortName == 'context-branch'),
        isTrue,
      );
      expect(
        sidebarBloc.state.tags.any((t) => t.name == 'v1.0.9-integration'),
        isTrue,
      );
      expect(
        sidebarBloc.state.stashes.any((s) => s.message.contains('integration-stash')),
        isTrue,
      );

      await gitService.popStash(gitRepo, 0);
      sidebarBloc.add(LoadSidebarEvent(gitRepo));
      await waitReal(600);
      expect(
        sidebarBloc.state.stashes.any((s) => s.message.contains('integration-stash')),
        isFalse,
      );
    });
  });
}

class TestFilePickerService implements FilePickerService {
  final String path;
  TestFilePickerService(this.path);

  @override
  Future<String?> getDirectoryPath({String? dialogTitle}) async => path;
}
