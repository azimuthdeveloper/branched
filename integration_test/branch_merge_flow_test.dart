import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:branched/main.dart';
import 'package:branched/core/locator.dart';
import 'package:branched/git_engine/git_service.dart';
import 'package:branched/features/repository_manager/repository_manager_bloc.dart';
import 'package:branched/features/sidebar/sidebar_bloc.dart';
import 'package:branched/features/sidebar/sidebar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:branched/git_engine/mock_git_service.dart';
import 'package:branched/core/file_picker_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    locator.registerLazySingleton<GitService>(() => MockGitService());
    locator.registerLazySingleton<FilePickerService>(() => TestFilePickerService());
  });

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
    expect(find.text('RECENT REPOSITORIES'), findsOneWidget);
    await capture('01_welcome_screen');

    // 2. Open repository
    // Click Open Repository Card (triggers mocked FilePickerService to return /root/my-project)
    await tester.tap(find.text('Open Repository'));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // 3. Verify Workspace renders
    expect(find.text('Changes'), findsWidgets);
    expect(find.text('main'), findsWidgets);
    await capture('02_workspace_loaded');

    // 4. Branch Checkout Flow
    // Tap on branch 'feature/auth' in the sidebar specifically
    final sidebarAuthFinder = find.descendant(
      of: find.byType(SidebarWidget),
      matching: find.text('feature/auth'),
    );
    await tester.tap(sidebarAuthFinder);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await capture('03_checkout_branch_complete');

    // 5. Switch to Changes/Staging Panel
    final sidebarChangesFinder = find.descendant(
      of: find.byType(SidebarWidget),
      matching: find.text('Changes'),
    );
    await tester.tap(sidebarChangesFinder);
    await tester.pumpAndSettle();
    expect(find.text('Unstaged Changes (3)'), findsOneWidget);
    expect(find.text('Staged Changes (1)'), findsOneWidget);
    await capture('04_staging_panel');

    // 6. Simulate Merge and Conflict resolution
    final BuildContext context = tester.element(find.byType(AppContentGate));
    context.read<RepositoryManagerBloc>().add(const SetDirtyTabEvent('/root/my-project', true));
    await tester.pumpAndSettle();

    // Type a commit message
    await tester.enterText(find.byType(TextField).last, 'feat: verified merge resolution');
    await tester.pumpAndSettle();
    await capture('05_commit_form_ready');

    // Tap Commit
    await tester.tap(find.text('Commit'));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await capture('06_flow_complete');
  });
}

class TestFilePickerService implements FilePickerService {
  @override
  Future<String?> getDirectoryPath({String? dialogTitle}) async {
    return '/root/my-project';
  }
}
