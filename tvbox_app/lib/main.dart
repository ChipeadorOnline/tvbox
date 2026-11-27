import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'screens/catalog_screen.dart';
import 'screens/license_screen.dart';
import 'services/background_service.dart';
import 'services/catalog_service.dart';
import 'services/download_service.dart';
import 'services/install_service.dart';
import 'services/license_service.dart';
import 'tv_navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final catalogService = CatalogService(sharedPreferences: prefs);
  final licenseService = LicenseService(sharedPreferences: prefs);

  try {
    await initBackgroundCheck();
  } on PlatformException catch (_) {
    // En algunos TVs el worker no está disponible; el chequeo al abrir basta.
  }

  runApp(
    TvboxApp(
      catalogService: catalogService,
      licenseService: licenseService,
      downloadService: DownloadService(),
      installService: InstallService(),
    ),
  );
}

class TvboxApp extends StatefulWidget {
  const TvboxApp({
    super.key,
    required this.catalogService,
    required this.licenseService,
    required this.downloadService,
    required this.installService,
  });

  final CatalogService catalogService;
  final LicenseService licenseService;
  final DownloadService downloadService;
  final InstallService installService;

  @override
  State<TvboxApp> createState() => _TvboxAppState();
}

enum _Stage { loading, login, ready, error }

class _TvboxAppState extends State<TvboxApp> with WidgetsBindingObserver {
  _Stage _stage = _Stage.loading;
  Catalog? _catalog;
  LicenseState? _license;
  String _error = '';
  bool _installing = false;
  bool _dialogOpen = false;
  bool _noticeScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _stage != _Stage.ready) return;
    // Si volvemos del instalador de Android, recargamos en silencio: mostrar
    // un diálogo justo en ese momento puede fallar en algunos TV Box.
    final afterInstaller = _installing;
    _installing = false;
    _start(showNotice: !afterInstaller);
  }

  Future<void> _start({bool showNotice = true}) async {
    if (mounted) setState(() => _stage = _Stage.loading);

    // Sobrevive al reinicio que hace Android al instalar un APK.
    final afterInstaller = await widget.catalogService.consumeInstallerNotice();
    final allowNotice = showNotice && !afterInstaller;

    final allowed = await widget.licenseService.isAllowed();
    if (!allowed) {
      if (mounted) setState(() => _stage = _Stage.login);
      return;
    }

    final license = await widget.licenseService.cachedState();
    if (license == null) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _error = 'No se pudo leer el estado de la licencia';
        });
      }
      return;
    }

    try {
      final catalog = await widget.catalogService.load();
      final hasNews = await widget.catalogService.consumePendingUpdate(catalog);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _license = license;
        _stage = _Stage.ready;
      });
      final selfUpdate = await _hasSelfUpdate(catalog);
      if (allowNotice && !_noticeScheduled) {
        _noticeScheduled = true;
        // Mostrar el diálogo apenas termina el setState puede fallar en TV Box:
        // el Navigator todavía no tiene lista la pantalla. Esperamos al frame.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _noticeScheduled = false;
          if (!mounted || _dialogOpen || _installing) return;
          try {
            if (selfUpdate) {
              await _showSelfUpdateNotice();
            } else if (hasNews) {
              await _showUpdateNotice(catalog);
            }
          } catch (e) {
            // Un aviso que no se muestra nunca debe dejar la app en error.
            debugPrint('No se pudo mostrar el aviso de actualización: $e');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _error = e.toString();
        });
      }
    }
  }

  Future<bool> _hasSelfUpdate(Catalog catalog) async {
    final own = await widget.installService.ownVersion();
    for (final app in catalog.apps) {
      if (app.id == 'tvbox-updater' && app.versionCode > own.versionCode) {
        return true;
      }
    }
    return false;
  }

  Future<void> _showSelfUpdateNotice() async {
    if (!mounted || _dialogOpen || _installing) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF111D28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: const [
              Icon(Icons.system_update, size: 32, color: Color(0xFF38BDF8)),
              SizedBox(width: 12),
              Text(
                'Actualización disponible',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ],
          ),
          content: const Text(
            'Hay una versión nueva del Actualizador TV. '
            'Andá a la tarjeta "Actualizador TV" y apretá Actualizar.',
            style: TextStyle(color: Color(0xFFC6D5E2), fontSize: 18),
          ),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext),
              style: TvStyles.button(const Color(0xFF0284C7)),
              child: const Text('Entendido', style: TextStyle(fontSize: 19)),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _showUpdateNotice(Catalog catalog) async {
    final count = catalog.apps.length;
    if (!mounted || _dialogOpen || _installing) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF111D28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Row(
            children: const [
              Icon(Icons.system_update, color: Color(0xFF38BDF8), size: 32),
              SizedBox(width: 12),
              Text(
                'Hay novedades',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ],
          ),
          content: Text(
            'El catálogo tiene $count aplicación${count == 1 ? '' : 'es'} disponible'
            '${count == 1 ? '' : 's'}. Revisá las actualizaciones para instalarlas.',
            style: const TextStyle(color: Color(0xFFC6D5E2), fontSize: 18),
          ),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                minimumSize: const Size(160, 52),
              ),
              child: const Text('Ver ahora', style: TextStyle(fontSize: 19)),
            ),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _logout() async {
    await widget.licenseService.clear();
    if (!mounted) return;
    setState(() {
      _stage = _Stage.login;
      _catalog = null;
      _license = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF111D28),
        ),
        scaffoldBackgroundColor: const Color(0xFF070E14),
        visualDensity: VisualDensity.comfortable,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF38BDF8)),
                SizedBox(height: 20),
                Text(
                  'Verificando licencia y catálogo...',
                  style: TextStyle(color: Color(0xFF9FB6C9), fontSize: 18),
                ),
              ],
            ),
          ),
        );
      case _Stage.login:
        return LicenseScreen(
          licenseService: widget.licenseService,
          onSuccess: () => _start(),
        );
      case _Stage.error:
        return TvNavigation(
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      size: 64,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No se pudo cargar: $_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFC6D5E2),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      autofocus: true,
                      onPressed: () => _start(),
                      style: TvStyles.button(const Color(0xFF0284C7)),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _Stage.ready:
        final catalog = _catalog;
        final license = _license;
        if (catalog == null || license == null) {
          return TvNavigation(
            child: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh,
                        size: 64,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Faltaron datos para abrir el catálogo. Probá de nuevo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFC6D5E2),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        autofocus: true,
                        onPressed: () => _start(),
                        style: TvStyles.button(const Color(0xFF0284C7)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return CatalogScreen(
          key: ValueKey('${catalog.signature}-${license.checkedAt}'),
          catalog: catalog,
          license: license,
          catalogService: widget.catalogService,
          licenseService: widget.licenseService,
          downloadService: widget.downloadService,
          installService: widget.installService,
          onLogout: _logout,
          onInstalling: (active) => _installing = active,
        );
    }
  }
}
