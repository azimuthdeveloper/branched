import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../git_engine/git_models.dart';

/// Modal prompt shown when a remote requires authentication. Works on all
/// platforms (desktop and Android). Returns null when the user cancels.
Future<GitAuthCredentials?> showCredentialsDialog(
  BuildContext context,
  String url, {
  String? failedUsername,
}) {
  final usernameController = TextEditingController(text: failedUsername ?? '');
  final passwordController = TextEditingController();

  return showDialog<GitAuthCredentials>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      void submit() {
        final username = usernameController.text.trim();
        final password = passwordController.text;
        if (username.isEmpty || password.isEmpty) return;
        Navigator.of(ctx).pop(GitAuthCredentials(username: username, password: password));
      }

      return AlertDialog(
        backgroundColor: FurcateTheme.darkBgSecondary,
        title: const Text('Authentication Required', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                url,
                style: const TextStyle(fontSize: 12, color: FurcateTheme.darkTextSecondary),
                overflow: TextOverflow.ellipsis,
              ),
              if (failedUsername != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'The previous credentials were rejected. Please try again.',
                  style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                key: const Key('auth_username_field'),
                controller: usernameController,
                autofocus: failedUsername == null,
                decoration: const InputDecoration(labelText: 'Username'),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('auth_password_field'),
                controller: passwordController,
                autofocus: failedUsername != null,
                obscureText: true,
                onSubmitted: (_) => submit(),
                decoration: const InputDecoration(
                  labelText: 'Password / Access token',
                  helperText: 'For GitHub and most providers, use a personal access token.',
                  helperStyle: TextStyle(fontSize: 11),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('auth_cancel_button'),
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('auth_ok_button'),
            onPressed: submit,
            child: const Text('Sign In'),
          ),
        ],
      );
    },
  );
}
