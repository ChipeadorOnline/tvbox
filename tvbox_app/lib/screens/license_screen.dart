import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/license_service.dart';
import '../tv_navigation.dart';
import 'diagnostic_screen.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({
    super.key,
    required this.licenseService,
    required this.onSuccess,
  });

  final LicenseService licenseService;
  final VoidCallback onSuccess;

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Si la clave quedó guardada, la mostramos lista para apretar Ingresar.
    widget.licenseService.getStoredKey().then((saved) {
      if (!mounted || saved == null || saved.isEmpty) return;
      setState(() => _controller.text = _normalizeKey(saved));
    });
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  static const String _version = 'v1.0.7';

  /// Mayúsculas y guiones: XXXX-XXXX-XXXX-XXXX. Se aplica al escribir y también
  /// al enviar, así funciona aunque el teclado del TV no avise de los cambios.
  static String _normalizeKey(String text) {
    final cleaned = text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final limited = cleaned.length > 16 ? cleaned.substring(0, 16) : cleaned;
    return limited.replaceAllMapped(
      RegExp(r'.{1,4}'),
      (match) => '${match.group(0)}-',
    ).replaceAll(RegExp(r'-$'), '');
  }

  void _formatKey(String text) {
    final formatted = _normalizeKey(text);
    if (formatted == _controller.text) return;
    _controller.value = _controller.value.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _submit() async {
    final key = _normalizeKey(_controller.text);
    if (key != _controller.text) {
      _controller.value = _controller.value.copyWith(
        text: key,
        selection: TextSelection.collapsed(offset: key.length),
      );
    }
    if (key.isEmpty) {
      setState(() => _error = 'Ingresá tu clave de acceso');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.licenseService.saveKey(key);
      final state = await widget.licenseService.validate(forceOnline: true);
      if (!state.active) {
        throw const LicenseException('Tu suscripción no está activa');
      }
      widget.onSuccess();
    } on LicenseException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'No se pudo verificar la clave: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvNavigation(
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Card(
                color: const Color(0xFF111D28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF24384A)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.tv, size: 64, color: Color(0xFF38BDF8)),
                      const SizedBox(height: 20),
                      const Text(
                        'Actualizador TV Box',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ingresá tu clave de abono para ver las aplicaciones disponibles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Color(0xFF9FB6C9)),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _controller,
                        focusNode: _focus,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                          LengthLimitingTextInputFormatter(19),
                        ],
                        onChanged: _formatKey,
                        onSubmitted: (_) => _submit(),
                        style: const TextStyle(fontSize: 22, color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Clave (XXXX-XXXX-XXXX-XXXX)',
                          labelStyle: const TextStyle(color: Color(0xFF9FB6C9)),
                          prefixIcon: const Icon(Icons.vpn_key, color: Color(0xFF38BDF8)),
                          filled: true,
                          fillColor: const Color(0xFF0A141D),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF38BDF8),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 17),
                        ),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        height: 60,
                        child: FilledButton(
                          autofocus: false,
                          onPressed: _busy ? null : _submit,
                          style: TvStyles.button(const Color(0xFF0284C7)),
                          child: _busy
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Ingresar', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DiagnosticScreen(
                                        licenseService: widget.licenseService,
                                        version: _version,
                                      ),
                                    ),
                                  ),
                          style: TvStyles.button(const Color(0xFF334155)),
                          child: const Text(
                            'Diagnóstico',
                            style: TextStyle(fontSize: 19),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Si el servidor está despertando, la espera puede '
                        'tardar hasta 1 minuto.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF5B7386), fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _version,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF5B7386), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
