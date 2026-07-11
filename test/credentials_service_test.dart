import 'package:flutter_test/flutter_test.dart';
import 'package:branched/git_engine/credentials_service.dart';
import 'package:branched/git_engine/git_models.dart';

void main() {
  group('CredentialsService Tests', () {
    late CredentialsService service;

    setUp(() {
      service = CredentialsService();
    });

    test('stores and retrieves credentials for standard HTTP/HTTPS URLs', () {
      const url = 'https://github.com/git-fixtures/basic.git';
      const creds = GitAuthCredentials(username: 'testuser', password: 'testpassword');

      expect(service.cachedFor(url), isNull);

      service.store(url, creds);

      final cached = service.cachedFor(url);
      expect(cached, isNotNull);
      expect(cached!.username, 'testuser');
      expect(cached.password, 'testpassword');
    });

    test('resolves same host key for different paths on HTTPS', () {
      const url1 = 'https://github.com/git-fixtures/basic.git';
      const url2 = 'https://github.com/another/repo.git';
      const creds = GitAuthCredentials(username: 'shareduser', password: 'sharedpassword');

      service.store(url1, creds);

      final cached = service.cachedFor(url2);
      expect(cached, isNotNull);
      expect(cached!.username, 'shareduser');
    });

    test('resolves host key for scp-style SSH URLs', () {
      const sshUrl = 'git@github.com:git-fixtures/basic.git';
      const httpsUrl = 'https://github.com/another/repo.git';
      const creds = GitAuthCredentials(username: 'git', password: 'sshkeypassword');

      service.store(sshUrl, creds);

      // Verify it resolves cache on standard HTTPS url because they share host key (github.com)
      final cached = service.cachedFor(httpsUrl);
      expect(cached, isNotNull);
      expect(cached!.username, 'git');
      expect(cached.password, 'sshkeypassword');
    });

    test('invalidates cache correctly', () {
      const url = 'https://gitlab.com/foo/bar.git';
      const creds = GitAuthCredentials(username: 'gitlabuser', password: 'gitlabpassword');

      service.store(url, creds);
      expect(service.cachedFor(url), isNotNull);

      service.invalidate(url);
      expect(service.cachedFor(url), isNull);
    });

    test('requestFor prompts registered handler and stores outcome', () async {
      const url = 'https://bitbucket.org/some/repo.git';
      const expectedCreds = GitAuthCredentials(username: 'bbuser', password: 'bbpassword');

      var promptCalled = false;
      service.prompt = (promptUrl, {failedUsername}) async {
        promptCalled = true;
        expect(promptUrl, url);
        expect(failedUsername, 'prevuser');
        return expectedCreds;
      };

      final result = await service.requestFor(url, failedUsername: 'prevuser');
      expect(promptCalled, isTrue);
      expect(result, expectedCreds);

      // Verify it was stored in cache automatically
      final cached = service.cachedFor(url);
      expect(cached, expectedCreds);
    });

    test('requestFor returns null and does not cache if handler returns null', () async {
      const url = 'https://bitbucket.org/some/repo.git';

      service.prompt = (promptUrl, {failedUsername}) async {
        return null; // user cancelled
      };

      final result = await service.requestFor(url);
      expect(result, isNull);
      expect(service.cachedFor(url), isNull);
    });
  });
}
