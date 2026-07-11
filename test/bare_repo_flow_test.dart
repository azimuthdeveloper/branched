import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:branched/git_engine/git_service_impl.dart';

void main() {
  late Directory tempDir;
  late RealGitService gitService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('branched_bare_test_');
    gitService = RealGitService();
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Bare Repository Flow - init, write, browse, edit, and commit', () async {
    final repoPath = p.join(tempDir.path, 'bare_repo.git');
    final gitRepo = await gitService.initRepository(repoPath, bare: true);
    
    // 1. Verify it is detected as a bare repository
    final isBare = await gitService.isBareRepository(gitRepo);
    expect(isBare, isTrue);

    // 2. Write initial file (the repository is empty)
    await gitService.writeAndCommitFile(
      gitRepo,
      'lib/main.dart',
      'void main() { print("hello world"); }',
      'feat: initial commit with main.dart',
    );

    // 3. Inspect tree files
    var files = await gitService.getTreeFiles(gitRepo);
    expect(files, contains('lib/main.dart'));
    expect(files.length, 1);

    // 4. Retrieve and verify content
    var content = await gitService.getFileContentAtRef(gitRepo, 'lib/main.dart');
    expect(content, 'void main() { print("hello world"); }');

    // 5. Add a second file (README.md)
    await gitService.writeAndCommitFile(
      gitRepo,
      'README.md',
      '# Branched Git Client',
      'docs: add readme',
    );

    // 6. Verify both files exist
    files = await gitService.getTreeFiles(gitRepo);
    expect(files, contains('lib/main.dart'));
    expect(files, contains('README.md'));
    expect(files.length, 2);

    // 7. Edit the first file (main.dart)
    await gitService.writeAndCommitFile(
      gitRepo,
      'lib/main.dart',
      'void main() { print("hello universe"); }',
      'feat: update main.dart output',
    );

    // 8. Verify the updated content
    content = await gitService.getFileContentAtRef(gitRepo, 'lib/main.dart');
    expect(content, 'void main() { print("hello universe"); }');
    
    // Verify readme content remains intact
    final readmeContent = await gitService.getFileContentAtRef(gitRepo, 'README.md');
    expect(readmeContent, '# Branched Git Client');
  });
}
