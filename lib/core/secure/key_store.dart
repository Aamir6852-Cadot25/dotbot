import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the user's own API keys. Never logged, never committed.
abstract class KeyStore {
  Future<String?> read(String provider);
  Future<void> write(String provider, String key);
}

class SecureKeyStore implements KeyStore {
  const SecureKeyStore([this._s = const FlutterSecureStorage()]);
  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String provider) => _s.read(key: 'apikey_$provider');

  @override
  Future<void> write(String provider, String key) =>
      _s.write(key: 'apikey_$provider', value: key);
}

class MemoryKeyStore implements KeyStore {
  final _m = <String, String>{};
  @override
  Future<String?> read(String provider) async => _m[provider];
  @override
  Future<void> write(String provider, String key) async => _m[provider] = key;
}
