import 'package:flutter/material.dart';

import '../models.dart';
import '../services/install_service.dart';
import '../services/license_service.dart';
import '../tv_navigation.dart';

/// Pantalla de diagnóstico: permite ver desde el TV qué está pasando con la
/// conexión y con la clave, sin necesidad de conectar la PC al box.
class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({
    super.key,
    required this.licenseService,
    this.installService,
    this.catalog,
    required this.version,
  });

  final LicenseService licenseService;
  final InstallService? installService;
  final Catalog? catalog;
  final String version;

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  String _text = 'Cargando diagnóstico...';
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    final buffer = StringBuffer(await widget.licenseService.diagnose(widget.version));
    final install = widget.installService;
    if (install != null) {
      final own = await install.ownVersion();
      buffer.writeln(
        'App instalada: ${own.versionName} (código ${own.versionCode})',
      );
      final catalog = widget.catalog;
      if (catalog != null) {
        buffer.writeln('Catálogo:');
        for (final app in catalog.apps) {
          final info = await install.installedInfo(app.packageName);
          buffer.writeln(
            '  ${app.name}: ${info.installed ? 'SÍ (${info.versionName}, código ${info.versionCode})' : 'NO detectada'} [${app.packageName}]',
          );
        }
      }
    }
    final result = buffer.toString();
    if (!mounted) return;
    setState(() {
      _text = result;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TvNavigation(
      child: Scaffold(
        backgroundColor: const Color(0xFF070E14),
        appBar: AppBar(
          title: const Text('Diagnóstico'),
          backgroundColor: const Color(0xFF111D28),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy)
                const LinearProgressIndicator(minHeight: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _text,
                    style: const TextStyle(
                      color: Color(0xFFC6D5E2),
                      fontSize: 18,
                      fontFamily: 'monospace',
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      autofocus: true,
                      onPressed: _busy ? null : _run,
                      style: TvStyles.button(const Color(0xFF0284C7)),
                      child: const Text('Repetir'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: TvStyles.button(const Color(0xFF334155)),
                      child: const Text('Volver'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
