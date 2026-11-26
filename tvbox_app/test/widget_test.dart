import 'package:flutter_test/flutter_test.dart';
import 'package:tvbox_updater/models.dart';

void main() {
  test('parsea un catálogo válido y calcula la firma', () {
    final catalog = Catalog.fromRawJson('''
    {
      "updatedAt": "2026-11-26",
      "apps": [
        {
          "id": "app1",
          "name": "App Uno",
          "fileName": "app-v2.apk",
          "url": "https://example.com/app-v2.apk",
          "version": "2.0",
          "versionCode": 2,
          "size": 1048576
        }
      ]
    }
    ''');

    expect(catalog.apps, hasLength(1));
    expect(catalog.apps.first.signature, 'app1:2');
    expect(catalog.apps.first.sizeLabel, '1.0 MB');
  });

  test('descarta entradas con URL no HTTPS', () {
    final catalog = Catalog.fromRawJson('''
    {
      "apps": [
        {
          "id": "mal",
          "fileName": "mal.apk",
          "url": "http://example.com/mal.apk"
        }
      ]
    }
    ''');
    expect(catalog.apps, isEmpty);
  });
}
