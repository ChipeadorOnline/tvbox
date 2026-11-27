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
  static const String keyTailKey = 'license_key_tail';

  /// Último código HTTP visto, para mostrarlo en pantalla si algo falla.
  int? lastStatusCode;
  String? lastServerMessage;

  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// En algunos TV Box el Android KeyStore falla. Guardamos también en
  /// SharedPreferences y leemos de ahí si el almacen seguro no responde.
  Future<String?> _readSecure() async {
    try {
      return await _secure.read(key: keyStorageKey);
    } catch (e) {
      debugPrint('Almacen seguro: $e');
      return null;
    }
  }

  Future<String?> getStoredKey() async {
    final secureKey = await _readSecure();
    if (secureKey != null && secureKey.trim().isNotEmpty) {
      return secureKey.trim();
    }
    return (await prefs).getString(keyStorageKey);
  }

  Future<void> saveKey(String key) async {
    final value = key.trim();
    await (await prefs).setString(keyStorageKey, value);
    try {
      await _secure.write(key: keyStorageKey, value: value);
    } catch (e) {
      debugPrint('No se pudo guardar en almacen seguro: $e');
    }
  }

  Future<void> clear() async {
    final p = await prefs;
    await p.remove(keyStorageKey);
    await p.remove(cacheKey);
    await p.remove(keyTailKey);
    try {
      await _secure.delete(key: keyStorageKey);
    } catch (_) {}
  }

  Future<http.Response> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConfig.apiUrl}$path');
    Object? lastError;
    // Render en plan gratuito se duerme: el primer request puede tardar
    // bastante en despertar. Probamos tres veces con tiempos crecientes.
    for (final seconds in [20, 45, 60]) {
      try {
        return await _client
            .post(
              uri,
              headers: const {'content-type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(Duration(seconds: seconds));
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    throw lastError ?? 'No se pudo conectar';
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
      response = await _post('/api/license/validate', {'key': key});
    } catch (e) {
      debugPrint('Validación de licencia (red): $e');
      // Si ya entramos con esta clave, la tolerancia sin internet aplica.
      // No exigimos la cola guardada: versiones anteriores no la escribieron.
      if (cachedRaw != null) {
        final cached = LicenseState.fromJson(jsonDecode(cachedRaw));
        final notExpired = cached.expiresAt == null ||
            cached.expiresAt!.isAfter(DateTime.now());
        final storedTail = p.getString(keyTailKey);
        final sameKey = storedTail == null ||
            storedTail == _tail(key) ||
            (await getStoredKey()) == key;
        if (cached.active && notExpired && sameKey &&
            DateTime.now().difference(cached.checkedAt).inDays <=
                AppConfig.offlineGraceDays) {
          return cached.copyWith(fromCache: true);
        }
      }
      throw const LicenseException(
        'Sin conexión con el servidor. La app está esperando a que '
        'despierte; probá de nuevo en unos segundos.',
      );
    }

    lastStatusCode = response.statusCode;
    if (response.statusCode == 401 || response.statusCode == 403) {
      try {
        lastServerMessage = jsonDecode(response.body)['error'] as String?;
      } catch (_) {}
      await p.remove(cacheKey);
      await p.remove(keyTailKey);
      throw LicenseException(
        'Clave inválida o vencida (código ${response.statusCode})',
      );
    }
    if (response.statusCode != 200) {
      throw LicenseException(
        'El servidor respondió código ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final state = LicenseState.fromJson(decoded as Map<String, dynamic>);
    await p.setString(cacheKey, jsonEncode(state.toJson()));
    await p.setString(keyTailKey, _tail(key));
    return state;
  }

  String _tail(String key) {
    final clean = key.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    return clean.length > 4 ? clean.substring(clean.length - 4) : clean;
  }

  /// Permite entrar con la última validación guardada si se cortó la red.
  Future<bool> canEnterOffline(String key) async {
    final p = await prefs;
    final raw = p.getString(cacheKey);
    if (raw == null) return false;
    final cached = LicenseState.fromJson(jsonDecode(raw));
    if (!cached.active) return false;
    if (cached.expiresAt != null && cached.expiresAt!.isBefore(DateTime.now())) {
      return false;
    }
    final storedTail = p.getString(keyTailKey);
    if (storedTail != null && storedTail != _tail(key)) return false;
    return DateTime.now().difference(cached.checkedAt).inDays <=
        AppConfig.offlineGraceDays;
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

  /// Información para el panel de diagnóstico de la app.
  Future<String> diagnose(String version) async {
    final out = StringBuffer();
    out.writeln('Versión: $version');
    out.writeln('API: ${AppConfig.apiUrl}');
    out.writeln('Hora del equipo: ${DateTime.now().toIso8601String()}');
    final key = await getStoredKey();
    out.writeln('Clave guardada: ${key ?? "(ninguna)"}');

    final watch = Stopwatch()..start();
    try {
      final r = await _client
          .get(Uri.parse('${AppConfig.apiUrl}/api/health'))
          .timeout(const Duration(seconds: 45));
      out.writeln(
        'Servidor: HTTP ${r.statusCode} (${watch.elapsed.inSeconds}s) ${r.body}',
      );
    } catch (e) {
      out.writeln('Servidor: ERROR $e (${watch.elapsed.inSeconds}s)');
    }

    if (key != null && key.isNotEmpty) {
      try {
        final r = await _post('/api/license/validate', {'key': key});
        out.writeln('Validación: HTTP ${r.statusCode}');
        out.writeln('Respuesta: ${utf8.decode(r.bodyBytes)}');
      } catch (e) {
        out.writeln('Validación: ERROR $e');
      }
    }
    return out.toString();
  }
}
