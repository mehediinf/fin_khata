import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

class BackupCryptoException implements Exception {
  const BackupCryptoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Encrypts/decrypts workspace backups with a user-chosen passphrase using
/// AES-256-GCM (authenticated encryption, so a wrong passphrase or tampered
/// file fails loudly instead of importing garbage) and PBKDF2-HMAC-SHA256
/// key derivation. The heavy KDF work runs in a background isolate via
/// [compute] so it never blocks the UI thread.
class BackupCryptoService {
  Future<String> encryptJson(Map<String, Object?> data, String passphrase) =>
      compute(_encrypt, _EncryptParams(data, passphrase));

  Future<Map<String, Object?>> decryptJson(
    String envelopeJson,
    String passphrase,
  ) => compute(_decrypt, _DecryptParams(envelopeJson, passphrase));
}

const _iterations = 100000;
const _keyLength = 32;
const _saltLength = 16;
const _ivLength = 12;

class _EncryptParams {
  const _EncryptParams(this.data, this.passphrase);
  final Map<String, Object?> data;
  final String passphrase;
}

class _DecryptParams {
  const _DecryptParams(this.envelopeJson, this.passphrase);
  final String envelopeJson;
  final String passphrase;
}

String _encrypt(_EncryptParams params) {
  final salt = _randomBytes(_saltLength);
  final iv = enc.IV(_randomBytes(_ivLength));
  final key = enc.Key(_deriveKey(params.passphrase, salt));
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  final encrypted = encrypter.encrypt(jsonEncode(params.data), iv: iv);
  return jsonEncode({
    'finkhataBackup': true,
    'version': 1,
    'kdf': 'pbkdf2-hmac-sha256',
    'iterations': _iterations,
    'cipher': 'aes-256-gcm',
    'salt': base64Encode(salt),
    'iv': base64Encode(iv.bytes),
    'ciphertext': encrypted.base64,
  });
}

Map<String, Object?> _decrypt(_DecryptParams params) {
  final Map<String, Object?> envelope;
  try {
    envelope = jsonDecode(params.envelopeJson) as Map<String, Object?>;
  } catch (_) {
    throw const BackupCryptoException('This is not a valid backup file.');
  }
  if (envelope['finkhataBackup'] != true ||
      envelope['cipher'] != 'aes-256-gcm' ||
      envelope['salt'] is! String ||
      envelope['iv'] is! String ||
      envelope['ciphertext'] is! String) {
    throw const BackupCryptoException(
      'This is not a valid encrypted FinKhata backup.',
    );
  }
  try {
    final salt = base64Decode(envelope['salt']! as String);
    final iv = enc.IV(base64Decode(envelope['iv']! as String));
    final key = enc.Key(_deriveKey(params.passphrase, salt));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final plainText = encrypter.decrypt64(
      envelope['ciphertext']! as String,
      iv: iv,
    );
    return jsonDecode(plainText) as Map<String, Object?>;
  } catch (_) {
    throw const BackupCryptoException(
      'Wrong passphrase, or the backup is corrupted.',
    );
  }
}

/// Single-block PBKDF2-HMAC-SHA256 (32-byte output == one HMAC-SHA256
/// block, so no need to chain multiple blocks together).
Uint8List _deriveKey(String passphrase, Uint8List salt) {
  final hmac = Hmac(sha256, utf8.encode(passphrase));
  final blockIndex = Uint8List(4)..buffer.asByteData().setUint32(0, 1);
  var u = hmac.convert([...salt, ...blockIndex]).bytes;
  final block = Uint8List.fromList(u);
  for (var i = 1; i < _iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < _keyLength; j++) {
      block[j] ^= u[j];
    }
  }
  return block;
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}
