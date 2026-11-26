import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../config.dart';
import '../models.dart';
import 'catalog_service.dart';

const String checkCatalogTask = 'checkCatalog';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != checkCatalogTask) return true;
    try {
      final response = await http
          .get(
            Uri.parse(AppConfig.catalogUrl),
            headers: const {'Cache-Control': 'no-cache'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return false;

      final catalog = Catalog.fromRawJson(utf8.decode(response.bodyBytes));
      final prefs = await SharedPreferences.getInstance();
      final previous = prefs.getString(CatalogService.signatureKey) ?? '';
      if (previous.isNotEmpty && previous != catalog.signature) {
        await prefs.setBool(CatalogService.pendingKey, true);
        await prefs.setString(CatalogService.cacheKey, catalog.rawJson);
      }
      return true;
    } catch (e) {
      debugPrint('Chequeo en segundo plano falló: $e');
      return false;
    }
  });
}

Future<void> initBackgroundCheck() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().cancelByUniqueName(checkCatalogTask);
  await Workmanager().registerPeriodicTask(
    checkCatalogTask,
    checkCatalogTask,
    frequency: AppConfig.backgroundCheckInterval,
    constraints: Constraints(networkType: NetworkType.connected),
  );
}
