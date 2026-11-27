import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models.dart';

class CatalogService {
  CatalogService({http.Client? client, SharedPreferences? sharedPreferences})
      : _client = client ?? http.Client(),
        _prefs = sharedPreferences;

  final http.Client _client;
  SharedPreferences? _prefs;

  static const String cacheKey = 'catalog_cache';
  static const String signatureKey = 'catalog_signature';
  static const String pendingKey = 'pending_catalog_update';

  Future<SharedPreferences> get prefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Trae el catálogo desde GitHub. Si falla la red, usa la última copia.
  Future<Catalog> load() async {
    Object? lastError;
    http.Response? response;
    for (final seconds in [20, 45]) {
      try {
        response = await _client
            .get(
              Uri.parse(AppConfig.catalogUrl),
              headers: const {'Cache-Control': 'no-cache'},
            )
            .timeout(Duration(seconds: seconds));
        break;
      } catch (e) {
        lastError = e;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    try {
      if (response == null) throw lastError ?? 'Sin respuesta del catálogo';
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final catalog = Catalog.fromRawJson(utf8.decode(response.bodyBytes));
      final p = await prefs;
      await p.setString(cacheKey, catalog.rawJson);
      return catalog;
    } catch (e) {
      debugPrint('No se pudo actualizar el catálogo: $e');
      final p = await prefs;
      final cached = p.getString(cacheKey);
      if (cached != null && cached.isNotEmpty) {
        return Catalog.fromRawJson(cached);
      }
      rethrow;
    }
  }

  /// true cuando cambió la lista o subió el versionCode de alguna app.
  Future<bool> consumePendingUpdate(Catalog catalog) async {
    final p = await prefs;
    final previous = p.getString(signatureKey) ?? '';
    final pending = p.getBool(pendingKey) ?? false;
    final changed = previous.isNotEmpty && previous != catalog.signature;
    await p.setString(signatureKey, catalog.signature);
    await p.setBool(pendingKey, false);
    return changed || pending;
  }
}
