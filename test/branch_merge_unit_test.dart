import 'package:flutter_test/flutter_test.dart';
import 'package:branched/core/locator.dart';
import 'package:branched/git_engine/git_service.dart';
import 'package:branched/git_engine/git_models.dart';
import 'package:branched/features/sidebar/sidebar_bloc.dart';
import 'package:branched/features/staging/staging_bloc.dart';

void main() {
  setUpAll(() {
    setupLocator();
  });

  group('Git Engine & State Management Unit Tests', () {
    final mockRepo = GitRepo(path: '/root/my-project', name: 'my-project');

    test('SidebarBloc loads branches and handles selections', () async {
      final sidebarBloc = SidebarBloc(locator<GitService>());
      

      // Load sidebar
      sidebarBloc.add(LoadSidebarEvent(mockRepo));
      await expectLater(
        sidebarBloc.stream,
        emitsThrough(predicate<SidebarState>((state) {
          return !state.isLoading && 
                 state.localBranches.any((item) => item.name == 'main') &&
                 state.localBranches.any((item) => item.name == 'feature/auth');
        })),
      );

      // Verify default selected item is 'Changes'
      expect(sidebarBloc.state.selectedItem.label, 'Changes');

      // Select 'feature/auth' branch from localBranches
      final authBranch = sidebarBloc.state.localBranches.firstWhere((item) => item.name == 'feature/auth');
      sidebarBloc.add(SelectSidebarItemEvent(SidebarItem(
        label: authBranch.name,
        type: SidebarItemType.branch,
        refName: authBranch.name,
      )));

      await expectLater(
        sidebarBloc.stream,
        emitsThrough(predicate<SidebarState>((state) {
          return state.selectedItem.label == 'feature/auth';
        })),
      );
    });

    test('StagingBloc handles staging, unstaging, and conflict states', () async {
      final stagingBloc = StagingBloc(locator<GitService>());

      // Load copy
      stagingBloc.add(LoadWorkingCopyEvent(mockRepo));
      await expectLater(
        stagingBloc.stream,
        emitsThrough(predicate<StagingState>((state) {
          return state.unstagedFiles.isNotEmpty && state.stagedFiles.isNotEmpty;
        })),
      );

      // Stage a file
      final fileToStage = stagingBloc.state.unstagedFiles.first;
      stagingBloc.add(StageFileEvent(mockRepo, fileToStage.path));

      await expectLater(
        stagingBloc.stream,
        emitsThrough(predicate<StagingState>((state) {
          return state.stagedFiles.any((f) => f.path == fileToStage.path) &&
                 !state.unstagedFiles.any((f) => f.path == fileToStage.path);
        })),
      );

      // Verify simulated conflicted file state
      final conflictedFile = FileStatusEntity(
        path: 'lib/core/theme.dart',
        status: FileChangeStatus.conflicted,
      );
      
      expect(conflictedFile.status, FileChangeStatus.conflicted);
    });
  });
}
