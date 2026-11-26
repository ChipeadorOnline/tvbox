import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

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
}
