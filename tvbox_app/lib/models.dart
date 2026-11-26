import 'dart:convert';

class CatalogApp {
  final String id;
  final String name;
  final String fileName;
  final String packageName;
  final String url;
  final String? version;
  final int versionCode;
  final int size;
  final String? sha256;
  final String? notes;

  const CatalogApp({
    required this.id,
    required this.name,
    required this.fileName,
    required this.url,
    required this.versionCode,
    String? packageName,
    this.version,
    this.size = 0,
    this.sha256,
    this.notes,
  }) : packageName = packageName ?? id;

  factory CatalogApp.fromJson(Map<String, dynamic> json) {
    final url = (json['url'] as String?)?.trim() ?? '';
    if (!url.startsWith('https://')) {
      throw const FormatException('La URL del APK debe ser HTTPS');
    }
    final id = (json['id'] as String?)?.trim();
    final fileName = (json['fileName'] as String?)?.trim();
    if (id == null || id.isEmpty || fileName == null || fileName.isEmpty) {
      throw const FormatException('Falta id o fileName en el catálogo');
    }
    return CatalogApp(
      id: id,
      name: (json['name'] as String?)?.trim() ?? id,
      fileName: fileName,
      url: url,
      packageName: (json['packageName'] as String?)?.trim(),
      version: json['version'] as String?,
      versionCode: _toInt(json['versionCode']) ?? 0,
      size: _toInt(json['size']) ?? 0,
      sha256: (json['sha256'] as String?)?.trim(),
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fileName': fileName,
        'url': url,
        'packageName': packageName,
        'version': version,
        'versionCode': versionCode,
        'size': size,
        'sha256': sha256,
        'notes': notes,
      };

  String get signature => '$id:$versionCode';

  String get sizeLabel {
    if (size <= 0) return '';
    final mb = size / 1048576;
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}

class Catalog {
  final String updatedAt;
  final List<CatalogApp> apps;

  const Catalog({required this.updatedAt, required this.apps});

  factory Catalog.fromJson(Map<String, dynamic> json) {
    final raw = json['apps'];
    if (raw is! List) {
      throw const FormatException('El catálogo no tiene una lista "apps"');
    }
    final apps = <CatalogApp>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      try {
        apps.add(CatalogApp.fromJson(item));
      } on FormatException {
        // Se ignoran entradas inválidas para no romper todo el catálogo.
      }
    }
    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Catalog(
      updatedAt: (json['updatedAt'] as String?)?.trim() ?? '',
      apps: apps,
    );
  }

  Map<String, dynamic> toJson() => {
        'updatedAt': updatedAt,
        'apps': apps.map((a) => a.toJson()).toList(),
      };

  String get signature => apps.map((a) => a.signature).join('|');

  String get rawJson => jsonEncode(toJson());

  factory Catalog.fromRawJson(String source) =>
      Catalog.fromJson(jsonDecode(source) as Map<String, dynamic>);
}

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  return null;
}

class LicenseState {
  final bool active;
  final DateTime? expiresAt;
  final String? username;
  final DateTime checkedAt;
  final bool fromCache;

  const LicenseState({
    required this.active,
    required this.checkedAt,
    this.expiresAt,
    this.username,
    this.fromCache = false,
  });

  factory LicenseState.fromJson(Map<String, dynamic> json) {
    return LicenseState(
      active: json['active'] is bool ? json['active'] as bool : false,
      expiresAt: DateTime.tryParse((json['expiresAt'] as String?) ?? ''),
      username: json['username'] as String?,
      checkedAt:
          DateTime.tryParse((json['checkedAt'] as String?) ?? '') ??
          DateTime.now(),
      fromCache: json['fromCache'] is bool ? json['fromCache'] as bool : false,
    );
  }

  Map<String, dynamic> toJson() => {
        'active': active,
        'expiresAt': expiresAt?.toIso8601String(),
        'username': username,
        'checkedAt': checkedAt.toIso8601String(),
      };

  LicenseState copyWith({bool? fromCache}) => LicenseState(
        active: active,
        expiresAt: expiresAt,
        username: username,
        checkedAt: checkedAt,
        fromCache: fromCache ?? this.fromCache,
      );

  String get expiryLabel {
    final expires = expiresAt;
    if (expires == null) return 'Sin vencimiento';
    final days = expires.difference(DateTime.now()).inDays;
    if (days < 0) return 'Vencida';
    if (days == 0) return 'Vence hoy';
    return 'Vence en $days día${days == 1 ? '' : 's'}';
  }
}

class LicenseException implements Exception {
  final String message;
  const LicenseException(this.message);

  @override
  String toString() => message;
}
