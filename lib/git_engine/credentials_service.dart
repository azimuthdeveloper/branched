import 'dart:async';

import 'git_models.dart';

/// Callback the UI layer registers to ask the user for credentials.
/// [failedUsername] carries the username of a previous rejected attempt so the
/// dialog can pre-fill it. Returning null means the user cancelled.
typedef CredentialsPrompt = Future<GitAuthCredentials?> Function(
  String url, {
  String? failedUsername,
});

/// Session-scoped credential broker shared between the git engine and the UI.
///
/// The engine calls [requestFor] when a remote rejects the current
/// credentials; the UI provides [prompt] (a dialog) at startup. Credentials
/// are cached in memory per host for the lifetime of the app only — nothing
/// is persisted to disk.
class CredentialsService {
  CredentialsPrompt? prompt;

  final Map<String, GitAuthCredentials> _sessionCache = {};

  String _hostKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.host.isNotEmpty) return uri.host;
    // scp-style SSH URL: git@github.com:user/repo.git
    final match = RegExp(r'^[^@]+@([^:]+):').firstMatch(url);
    if (match != null) return match.group(1)!;
    return url;
  }

  GitAuthCredentials? cachedFor(String url) => _sessionCache[_hostKey(url)];

  void store(String url, GitAuthCredentials credentials) {
    _sessionCache[_hostKey(url)] = credentials;
  }

  void invalidate(String url) {
    _sessionCache.remove(_hostKey(url));
  }

  /// Asks the user for credentials for [url]. Returns null when no prompt is
  /// registered (headless/test environment) or the user cancelled.
  Future<GitAuthCredentials?> requestFor(String url, {String? failedUsername}) async {
    final handler = prompt;
    if (handler == null) return null;
    final credentials = await handler(url, failedUsername: failedUsername);
    if (credentials != null) store(url, credentials);
    return credentials;
  }
}
