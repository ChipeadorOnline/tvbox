import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

import '../models.dart';
import '../services/catalog_service.dart';
import '../services/download_service.dart';
import '../services/install_service.dart';
import '../services/license_service.dart';
import '../tv_navigation.dart';
import 'diagnostic_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.catalog,
    required this.license,
    required this.catalogService,
    required this.licenseService,
    required this.downloadService,
    required this.installService,
    required this.onLogout,
  });

  final Catalog catalog;
  final LicenseState license;
  final CatalogService catalogService;
  final LicenseService licenseService;
  final DownloadService downloadService;
  final InstallService installService;
  final VoidCallback onLogout;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Catalog _catalog;
  late LicenseState _license;
  final Set<String> _busy = <String>{};
  final Map<String, double> _progress = <String, double>{};
  final Map<String, InstalledInfo> _installed = <String, InstalledInfo>{};
  String? _message;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog;
    _license = widget.license;
    _reloadInstalled();
  }

  Future<void> _reloadInstalled() async {
    final own = await widget.installService.ownVersion();
    final entries = await Future.wait(
      _catalog.apps.map(
        (app) => widget.installService.installedInfo(app.packageName),
      ),
    );
    if (!mounted) return;
    setState(() {
      _installed.clear();
      for (var i = 0; i < _catalog.apps.length; i++) {
        final app = _catalog.apps[i];
        // Para esta app usamos siempre la versión propia: evita depender de
        // restricciones de visibilidad de paquetes en algunos TV Box.
        _installed[app.id] = own.installed && app.packageName == own.packageName
            ? own
            : entries[i];
      }
    });
  }

  Future<void> _open(CatalogApp app) async {
    final ok = await widget.installService.openApp(app.packageName);
    if (!ok && mounted) {
      setState(() => _message = 'No se pudo abrir ${app.name}');
    }
  }

  Future<void> _uninstall(CatalogApp app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111D28),
        title: Text('Desinstalar ${app.name}?', style: const TextStyle(color: Colors.white)),
        content: const Text(
          'Se abrirá el diálogo de Android para confirmar.',
          style: TextStyle(color: Color(0xFFC6D5E2)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: TvStyles.button(const Color(0xFFB91C1C)),
            child: const Text('Desinstalar'),
          ),
        ],
      ),
    );
    if (confirm ?? false) {
      await widget.installService.uninstall(app.packageName);
      await _reloadInstalled();
    }
  }

  @override
  void didUpdateWidget(covariant CatalogScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog != widget.catalog) {
      setState(() => _catalog = widget.catalog);
      _reloadInstalled();
    }
    if (oldWidget.license != widget.license) {
      setState(() => _license = widget.license);
    }
  }

  void _openDiagnostic() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiagnosticScreen(
          licenseService: widget.licenseService,
          installService: widget.installService,
          catalog: _catalog,
          version: 'v1.0.9',
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    try {
      final updated = await widget.catalogService.load();
      if (mounted) {
        setState(() => _catalog = updated);
        await _reloadInstalled();
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'No se pudo actualizar el catálogo');
    }
  }

  Future<void> _install(CatalogApp app) async {
    setState(() {
      _busy.add(app.id);
      _progress[app.id] = 0;
      _message = 'Descargando ${app.name}...';
    });

    try {
      final canInstall = await widget.installService.canInstall();
      if (!canInstall && mounted) {
        final goSettings = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF111D28),
            title: const Text('Permiso de instalación', style: TextStyle(color: Colors.white)),
            content: const Text(
              'Android TV necesita permiso para instalar APKs. Abrí los ajustes, activá tu app y volvé.',
              style: TextStyle(color: Color(0xFFC6D5E2)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Abrir ajustes'),
              ),
            ],
          ),
        );
        if (goSettings ?? false) {
          await widget.installService.openUnknownSourcesSettings();
        }
        return;
      }

      final file = await widget.downloadService.download(
        app,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress[app.id] = total > 0 ? (received / total).clamp(0.0, 1.0) : 0;
          });
        },
      );

      if (!await file.exists()) {
        throw const FileSystemException('El APK descargado no existe');
      }

      if (mounted) {
        setState(() => _message = 'Abriendo el instalador de Android...');
      }
      final result = await widget.installService.openApk(file);
      if (result.type != ResultType.done && mounted) {
        setState(() => _message = 'No se pudo abrir el instalador: ${result.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy.remove(app.id);
          _progress.remove(app.id);
        });
        _reloadInstalled();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvNavigation(
      child: Scaffold(
      backgroundColor: const Color(0xFF070E14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1720),
        title: const Text(
          'Actualizador TV Box',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        actions: [
          Chip(
            avatar: const Icon(Icons.schedule, size: 18),
            label: Text(_license.expiryLabel),
            backgroundColor: const Color(0xFF15293A),
            labelStyle: const TextStyle(color: Color(0xFFBFE3FA)),
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Actualizar lista',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          TextButton.icon(
            onPressed: _openDiagnostic,
            icon: const Icon(Icons.info_outline, size: 20),
            label: const Text('Diagnóstico', style: TextStyle(fontSize: 18)),
            style: TvStyles.button(const Color(0xFF334155)).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(140, 44)),
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: () => SystemNavigator.pop(),
            icon: const Icon(Icons.exit_to_app, size: 20),
            label: const Text('Salir', style: TextStyle(fontSize: 18)),
            style: TvStyles.button(const Color(0xFF334155)).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(150, 44)),
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Cambiar clave', style: TextStyle(fontSize: 18)),
            style: TvStyles.button(const Color(0xFF334155)).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(150, 44)),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF102638),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1C4966)),
                ),
                child: Text(
                  _message!,
                  style: const TextStyle(color: Color(0xFF9AD9FF), fontSize: 17),
                ),
              ),
            Expanded(
              child: _catalog.apps.isEmpty
                  ? const Center(
                      child: Text(
                        'El catálogo está vacío. Editá catalog.json en GitHub para agregar apps.',
                        style: TextStyle(color: Color(0xFF9FB6C9), fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 2.1,
                      ),
                      itemCount: _catalog.apps.length,
                      itemBuilder: (context, index) {
                        final app = _catalog.apps[index];
                        final busy = _busy.contains(app.id);
                        final progress = _progress[app.id] ?? 0;
                        final info = _installed[app.id] ??
                            const InstalledInfo(
                              installed: false,
                              versionCode: 0,
                              versionName: '',
                            );
                        return Card(
                          color: info.installed
                              ? const Color(0xFF10281C)
                              : const Color(0xFF111D28),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: info.installed
                                  ? const Color(0xFF166534)
                                  : const Color(0xFF24384A),
                              width: info.installed ? 2 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  [
                                    if (app.version != null)
                                      'Versión disponible: v${app.version}',
                                    app.sizeLabel,
                                  ].where((s) => s.isNotEmpty).join('  ·  '),
                                  style: const TextStyle(
                                    color: Color(0xFFBFE3FA),
                                    fontSize: 15,
                                  ),
                                ),
                                if (info.installed) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Instalada ${info.label}',
                                    style: const TextStyle(
                                      color: Color(0xFF86EFAC),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (busy)
                                  LinearProgressIndicator(value: progress > 0 ? progress : null)
                                else
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                        width: double.infinity,
                                        height: 44,
                                        child: FilledButton.icon(
                                          autofocus: index == 0,
                                          onPressed: () => _install(app),
                                          icon: const Icon(Icons.download, size: 19),
                                          label: Text(
                                            info.installed
                                                ? 'Actualizar a v${app.version}'
                                                : 'Instalar v${app.version}',
                                            style: const TextStyle(fontSize: 15),
                                          ),
                                          style: TvStyles.button(
                                            const Color(0xFF0284C7),
                                          ).copyWith(
                                            minimumSize: WidgetStateProperty.all(
                                              const Size(190, 44),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (info.installed) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextButton.icon(
                                                onPressed: () => _open(app),
                                                icon: const Icon(Icons.launch, size: 18),
                                                label: const Text(
                                                  'Abrir',
                                                  style: TextStyle(fontSize: 15),
                                                ),
                                                style: TvStyles.button(
                                                  const Color(0xFF166534),
                                                ).copyWith(
                                                  minimumSize: WidgetStateProperty.all(
                                                    const Size(90, 38),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextButton.icon(
                                                onPressed: () => _uninstall(app),
                                                icon: const Icon(Icons.delete, size: 18),
                                                label: const Text(
                                                  'Borrar',
                                                  style: TextStyle(fontSize: 15),
                                                ),
                                                style: TvStyles.button(
                                                  const Color(0xFF7F1D1D),
                                                ).copyWith(
                                                  minimumSize: WidgetStateProperty.all(
                                                    const Size(90, 38),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
