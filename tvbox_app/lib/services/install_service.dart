import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

class InstalledInfo {
  const InstalledInfo({
    required this.installed,
    required this.versionCode,
    required this.versionName,
    this.packageName = '',
  });

  final String packageName;
  final bool installed;
  final int versionCode;
  final String versionName;

  factory InstalledInfo.fromMap(Map<dynamic, dynamic> map) => InstalledInfo(
        packageName: (map['packageName'] as String?) ?? '',
        installed: map['installed'] == true,
        versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
        versionName: (map['versionName'] as String?) ?? '',
      );

  String get label =>
      installed ? (versionName.isEmpty ? 'Instalada' : 'v$versionName') : '';
}

class InstallService {
  static const MethodChannel _channel =
      MethodChannel('com.chipeadoronline.tvbox_updater/install');

  /// Android 8+ exige permiso explícito para instalar APKs fuera de Play.
  Future<bool> canInstall() async {
    try {
      return (await _channel.invokeMethod<bool>('canInstall')) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openUnknownSourcesSettings() async {
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  /// Abre el instalador del sistema con el APK ya descargado.
  Future<OpenResult> openApk(File file) => OpenFilex.open(file.path);

  Future<InstalledInfo> installedInfo(String packageName) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'installedInfo',
        {'packageName': packageName},
      );
      if (result == null) return const InstalledInfo(installed: false, versionCode: 0, versionName: '');
      return InstalledInfo.fromMap(result);
    } on MissingPluginException {
      return const InstalledInfo(installed: false, versionCode: 0, versionName: '');
    }
  }

  Future<InstalledInfo> ownVersion() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('ownVersion');
      if (result == null) return const InstalledInfo(installed: false, versionCode: 0, versionName: '');
      return InstalledInfo.fromMap(result);
    } on MissingPluginException {
      return const InstalledInfo(installed: false, versionCode: 0, versionName: '');
    }
  }

  Future<bool> openApp(String packageName) async {
    try {
      return (await _channel.invokeMethod<bool>('openApp', {
            'packageName': packageName,
          })) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre el diálogo del sistema para desinstalar. Android no permite hacerlo
  /// en silencio salvo que el dispositivo sea propiedad de la organización.
  Future<bool> uninstall(String packageName) async {
    try {
      return (await _channel.invokeMethod<bool>('uninstall', {
            'packageName': packageName,
          })) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
