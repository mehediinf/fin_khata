import 'dart:convert';

import 'package:fin_khata/services/backup_crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = BackupCryptoService();
  const data = {
    'schemaVersion': 1,
    'workspaceId': 'w1',
    'tables': {
      'workspaces': [
        {'id': 'w1', 'name': 'Personal'},
      ],
    },
  };

  test('round-trips data with the correct passphrase', () async {
    final envelope = await service.encryptJson(data, 'correct-horse');
    final decrypted = await service.decryptJson(envelope, 'correct-horse');
    expect(decrypted, equals(data));
  });

  test('rejects a wrong passphrase', () async {
    final envelope = await service.encryptJson(data, 'correct-horse');
    expect(
      () => service.decryptJson(envelope, 'wrong-passphrase'),
      throwsA(isA<BackupCryptoException>()),
    );
  });

  test('rejects a tampered ciphertext', () async {
    final envelope = await service.encryptJson(data, 'correct-horse');
    final parsed = jsonDecode(envelope) as Map<String, Object?>;
    final cipher = parsed['ciphertext'] as String;
    parsed['ciphertext'] = '${cipher.substring(0, cipher.length - 4)}abcd';
    expect(
      () => service.decryptJson(jsonEncode(parsed), 'correct-horse'),
      throwsA(isA<BackupCryptoException>()),
    );
  });

  test('rejects text that is not a FinKhata backup envelope', () async {
    expect(
      () => service.decryptJson('not even json', 'anything'),
      throwsA(isA<BackupCryptoException>()),
    );
    expect(
      () => service.decryptJson(jsonEncode({'hello': 'world'}), 'anything'),
      throwsA(isA<BackupCryptoException>()),
    );
  });
}
