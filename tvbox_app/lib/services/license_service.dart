import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

class LicenseService {
  LicenseService({
    FlutterSecureStorage? secure,
    SharedPreferences? sharedPreferences,
  })  : _secure = secure ?? const FlutterSecureStorage(),
        _prefs = sharedPreferences;

  final FlutterSecureStorage _secure;
  SharedPreferences? _prefs;
  final http.Client _client = http.Client();

  static const String keyStorageKey = 'license_key';
  static const String cacheKey = 'license_cache';

  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> getStoredKey() => _secure.read(key: keyStorageKey);

  Future<void> saveKey(String key) =>
      _secure.write(key: keyStorageKey, value: key.trim());

  Future<void> clear() async {
    await _secure.delete(key: keyStorageKey);
    await (await prefs).remove(cacheKey);
  }

  /// Verifica la clave contra el backend. Usa caché reciente si está disponible.
  Future<LicenseState> validate({bool forceOnline = false}) async {
    final key = await getStoredKey();
    if (key == null || key.isEmpty) {
      throw const LicenseException('Ingresá tu clave de acceso');
    }

    final p = await prefs;
    final cachedRaw = p.getString(cacheKey);
    if (!forceOnline && cachedRaw != null) {
      final cached = LicenseState.fromJson(jsonDecode(cachedRaw));
      final age = DateTime.now().difference(cached.checkedAt);
      if (cached.active && age.inHours < AppConfig.licenseCheckHours) {
        return cached.copyWith(fromCache: true);
      }
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${AppConfig.apiUrl}/api/license/validate'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({'key': key}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const LicenseException(
        'Sin conexión con el servidor de licencias. Intentá de nuevo.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      await p.remove(cacheKey);
      throw const LicenseException('Clave inválida o vencida');
    }
    if (response.statusCode != 200) {
      throw const LicenseException('El servidor no respondió correctamente');
    }

    final state = LicenseState.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
    await p.setString(cacheKey, jsonEncode(state.toJson()));
    return state;
  }

  /// Permite entrar con la última validación guardada hasta 7 días sin internet.
  Future<bool> isAllowed({bool forceOnline = false}) async {
    if (!forceOnline) {
      try {
        return (await validate()).active;
      } on LicenseException catch (e) {
        debugPrint('Validación de licencia: $e');
      }
    }

    final raw = (await prefs).getString(cacheKey);
    if (raw == null) return false;
    final cached = LicenseState.fromJson(jsonDecode(raw));
    if (!cached.active) return false;
    if (cached.expiresAt != null && cached.expiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    return DateTime.now().difference(cached.checkedAt).inDays <=
        AppConfig.offlineGraceDays;
  }

  Future<LicenseState?> cachedState() async {
    final raw = (await prefs).getString(cacheKey);
    if (raw == null) return null;
    return LicenseState.fromJson(jsonDecode(raw));
  }
}
