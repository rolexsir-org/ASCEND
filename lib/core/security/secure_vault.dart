import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultException implements Exception {
  const VaultException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// AES-256-GCM field/blob encryption. The random data key is stored only in
/// Android Keystore-backed flutter_secure_storage; ciphertext is authenticated.
class SecureVault {
  SecureVault({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _keyName = 'ascend.data-key.v1';
  static const _formatVersion = 1;
  final FlutterSecureStorage _secureStorage;
  final AesGcm _cipher = AesGcm.with256bits();
  SecretKey? _key;

  Future<void> initialize({required bool encryptedRecordsExist}) async {
    final encoded = await _secureStorage.read(key: _keyName);
    if (encoded != null) {
      try {
        final bytes = base64Url.decode(encoded);
        if (bytes.length != 32) throw const FormatException('Unexpected key length');
        _key = SecretKey(bytes);
        return;
      } on FormatException {
        throw const VaultException('The secure storage key is damaged. Existing data was preserved.');
      }
    }
    if (encryptedRecordsExist) {
      throw const VaultException('The secure storage key is unavailable. Existing encrypted data was preserved and cannot be opened.');
    }
    final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    await _secureStorage.write(key: _keyName, value: base64UrlEncode(bytes));
    _key = SecretKey(bytes);
  }

  Future<Uint8List> encrypt(Uint8List plaintext) async {
    final key = _key;
    if (key == null) throw const VaultException('Secure storage has not been initialized.');
    final box = await _cipher.encrypt(plaintext, secretKey: key);
    final result = BytesBuilder(copy: false)
      ..add([_formatVersion, box.nonce.length, box.mac.bytes.length])
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return result.takeBytes();
  }

  Future<Uint8List> decrypt(Uint8List sealed) async {
    final key = _key;
    if (key == null) throw const VaultException('Secure storage has not been initialized.');
    if (sealed.length < 3 || sealed[0] != _formatVersion) {
      throw const VaultException('Encrypted data has an unsupported format.');
    }
    final nonceLength = sealed[1];
    final macLength = sealed[2];
    if (nonceLength == 0 || macLength == 0 || sealed.length < 3 + nonceLength + macLength) {
      throw const VaultException('Encrypted data is truncated.');
    }
    final nonceStart = 3;
    final macStart = nonceStart + nonceLength;
    final ciphertextStart = macStart + macLength;
    final box = SecretBox(
      sealed.sublist(ciphertextStart),
      nonce: sealed.sublist(nonceStart, macStart),
      mac: Mac(sealed.sublist(macStart, ciphertextStart)),
    );
    try {
      return Uint8List.fromList(await _cipher.decrypt(box, secretKey: key));
    } on SecretBoxAuthenticationError {
      throw const VaultException('Encrypted data failed authentication. It was not modified.');
    }
  }

  Future<String> encryptText(String clearText) async =>
      base64UrlEncode(await encrypt(Uint8List.fromList(utf8.encode(clearText))));

  Future<String> decryptText(String ciphertext) async {
    try {
      final bytes = await decrypt(Uint8List.fromList(base64Url.decode(ciphertext)));
      return utf8.decode(bytes);
    } on FormatException {
      throw const VaultException('Encrypted text is malformed.');
    }
  }

  Future<void> destroyKeyAfterDataPurge() async {
    _key = null;
    await _secureStorage.delete(key: _keyName);
  }
}

/// App-private photos are AES-GCM encrypted before they touch persistent storage.
class PrivatePhotoStore {
  PrivatePhotoStore(this._vault);
  final SecureVault _vault;

  Future<Directory> _photoDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(appDir.path, 'ascend_private', 'photos'));
    await directory.create(recursive: true);
    return directory;
  }

  Future<String> save(Uint8List imageBytes, {required String photoId}) async {
    if (imageBytes.isEmpty || imageBytes.length > 20 * 1024 * 1024) {
      throw const VaultException('Photo size is outside the supported limit.');
    }
    final directory = await _photoDirectory();
    final fileName = '$photoId.asc';
    final target = File(p.join(directory.path, fileName));
    final temporary = File('${target.path}.pending');
    try {
      final sealed = await _vault.encrypt(imageBytes);
      await temporary.writeAsBytes(sealed, flush: true);
      await temporary.rename(target.path);
      return fileName;
    } on Object {
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  Future<Uint8List> read(String fileName) async {
    _validateFileName(fileName);
    final directory = await _photoDirectory();
    final file = File(p.join(directory.path, fileName));
    if (!await file.exists()) throw const VaultException('The private photo file is missing.');
    return _vault.decrypt(await file.readAsBytes());
  }

  Future<void> delete(String fileName) async {
    _validateFileName(fileName);
    final directory = await _photoDirectory();
    final file = File(p.join(directory.path, fileName));
    if (await file.exists()) await file.delete();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  Future<void> deleteAll() async {
    final appDir = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(appDir.path, 'ascend_private', 'photos'));
    if (await directory.exists()) await directory.delete(recursive: true);
    await clearTransientCameraCaptures();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  /// CameraX writes unencrypted CAP*.jpg files to the app cache before ASCEND
  /// accepts and encrypts a scan. Remove stale captures from interrupted flows.
  Future<void> clearTransientCameraCaptures() async {
    final cacheDirectory = await getTemporaryDirectory();
    if (!await cacheDirectory.exists()) return;
    final captureName = RegExp(r'^CAP[^/]*\.jpg$', caseSensitive: false);
    await for (final entity in cacheDirectory.list(followLinks: false)) {
      if (entity is File && captureName.hasMatch(p.basename(entity.path))) {
        await entity.delete();
      }
    }
  }

  Future<void> removeTemporaryArtifacts() async {
    final directory = await _photoDirectory();
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.pending')) await entity.delete();
    }
  }

  Future<void> removeUnreferencedFiles(Set<String> referencedFileNames) async {
    final directory = await _photoDirectory();
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.asc')) continue;
      if (!referencedFileNames.contains(name)) await entity.delete();
    }
  }

  void _validateFileName(String fileName) {
    if (!RegExp(r'^[a-f0-9-]{36}\.asc$').hasMatch(fileName)) {
      throw const VaultException('Invalid private photo identifier.');
    }
  }
}
