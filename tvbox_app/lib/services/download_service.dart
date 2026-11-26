import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models.dart';

class DownloadService {
  DownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Descarga el APK a una carpeta privada de la app (sirve FileProvider).
  Future<File> download(
    CatalogApp app, {
    void Function(int received, int total)? onProgress,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}downloads');
    await dir.create(recursive: true);
    final safeName = app.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final target = File('${dir.path}${Platform.pathSeparator}$safeName');

    if (await target.exists()) {
      final length = await target.length();
      if (app.size <= 0 || length == app.size) {
        if (await _matchesDigest(target, app.sha256)) return target;
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
    return target;
  }

  Future<bool> _matchesDigest(File file, String? expected) async {
    if (expected == null || expected.isEmpty) return true;
    final bytes = await file.readAsBytes();
    final actual = sha256.convert(bytes).toString();
    return actual.toLowerCase() == expected.toLowerCase();
  }

  Future<void> remove(CatalogApp app) async {
    final base = await getApplicationDocumentsDirectory();
    final safeName = app.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      '${base.path}${Platform.pathSeparator}downloads${Platform.pathSeparator}$safeName',
    );
    if (await file.exists()) await file.delete();
  }
}
