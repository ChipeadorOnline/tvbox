/// Configuración compilada en la app.
///
/// Ejemplo:
/// flutter build apk --release \
///   --dart-define=API_URL=https://licencias.tudominio.com \
///   --dart-define=CATALOG_URL=https://raw.githubusercontent.com/ChipeadorOnline/tvbox/main/catalog.json
class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String catalogUrl = String.fromEnvironment(
    'CATALOG_URL',
    defaultValue:
        'https://raw.githubusercontent.com/ChipeadorOnline/tvbox/main/catalog.json',
  );

  /// Días de tolerancia sin internet antes de pedir la clave otra vez.
  static const int offlineGraceDays = 7;

  /// Cada cuánto se comprueba la licencia estando online.
  static const int licenseCheckHours = 24;

  static const Duration backgroundCheckInterval = Duration(hours: 6);
}
