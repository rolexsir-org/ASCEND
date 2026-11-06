import 'dart:convert';

import 'package:ascend/core/security/secure_vault.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  test('AES-GCM round-trips and rejects a modified ciphertext', () async {
    final storage = _MemorySecureStorage();
    final vault = SecureVault(secureStorage: storage);
    await vault.initialize(encryptedRecordsExist: false);

    final clear = 'private local profile';
    final sealed = await vault.encryptText(clear);
    expect(sealed, isNot(contains(clear)));
    expect(await vault.decryptText(sealed), clear);

    final raw = base64Url.decode(sealed);
    raw[raw.length - 1] ^= 1;
    await expectLater(
      vault.decryptText(base64UrlEncode(raw)),
      throwsA(isA<VaultException>()),
    );
  });

  test('a missing key never silently replaces ciphertext-bearing data', () async {
    final storage = _MemorySecureStorage();
    final vault = SecureVault(secureStorage: storage);

    await expectLater(
      vault.initialize(encryptedRecordsExist: true),
      throwsA(isA<VaultException>()),
    );
    expect(storage.values, isEmpty);
  });

  test('destroying the data key makes old ciphertext unreadable', () async {
    final storage = _MemorySecureStorage();
    final vault = SecureVault(secureStorage: storage);
    await vault.initialize(encryptedRecordsExist: false);
    final sealed = await vault.encryptText('old data');

    await vault.destroyKeyAfterDataPurge();
    await vault.initialize(encryptedRecordsExist: false);

    await expectLater(vault.decryptText(sealed), throwsA(isA<VaultException>()));
  });
}
