import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

class DownloadService {
  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}downloads');
    await dir.create(recursive: true);
    return dir;
  }

  /// El nombre incluye el versionCode: así una versión nueva nunca reutiliza
  /// el APK guardado por una versión anterior.
  String _fileName(CatalogApp app) =>
      '${app.id}_${app.versionCode}_${app.fileName}'
          .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Future<File> _target(CatalogApp app) async {
    final dir = await _downloadsDir();
    return File('${dir.path}${Platform.pathSeparator}${_fileName(app)}');
  }

  /// Descarga el APK a una carpeta privada de la app (sirve FileProvider).
  Future<File> download(
    CatalogApp app, {
    void Function(int received, int total)? onProgress,
  }) async {
    final target = await _target(app);

    if (await target.exists()) {
      final length = await target.length();
      if (app.size <= 0 || length == app.size) {
        if (await _matchesDigest(target, app.sha256)) {
          await _removeLegacy(app);
          return target;
        }
      }
    }

    final request = http.Request('GET', Uri.parse(app.url));
    final response = await _client.send(request).timeout(const Duration(minutes: 5));
    if (response.statusCode != 200) {
      throw Exception('No se pudo descargar (HTTP ${response.statusCode})');
    }

    final total =
        int.tryParse(response.headers['content-length'] ?? '') ?? app.size;
    final sink = target.openWrite();
    var received = 0;
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }

    if (app.size > 0 && received != app.size) {
      throw Exception('Descarga incompleta ($received de ${app.size} bytes)');
    }
    if (!await _matchesDigest(target, app.sha256)) {
      throw Exception('El APK no coincide con el SHA-256 publicado');
    }
    await _removeLegacy(app);
    return target;
  }

  /// Borra el archivo sin versión que usaban las builds anteriores.
  Future<void> _removeLegacy(CatalogApp app) async {
    final dir = await _downloadsDir();
    final legacyName = app.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final legacy = File('${dir.path}${Platform.pathSeparator}$legacyName');
    if (await legacy.exists()) await legacy.delete();
  }

  Future<bool> _matchesDigest(File file, String? expected) async {
    if (expected == null || expected.isEmpty) return true;
    final bytes = await file.readAsBytes();
    final actual = sha256.convert(bytes).toString();
    return actual.toLowerCase() == expected.toLowerCase();
  }

  Future<void> remove(CatalogApp app) async {
    final target = await _target(app);
    if (await target.exists()) await target.delete();
    await _removeLegacy(app);
  }
}
