import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('socket debug test', () async {
    try {
      print('Connecting to github.com:443...');
      final socket = await Socket.connect('github.com', 443, timeout: const Duration(seconds: 5));
      print('Connection succeeded!');
      socket.destroy();
    } catch (e, stack) {
      print('Connection failed: $e');
      print(stack);
      rethrow;
    }
  });
}
