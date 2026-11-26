import 'package:flutter/material.dart';

import '../models.dart';
import '../services/license_service.dart';

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
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _controller.text.trim();
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
    } catch (_) {
      setState(() => _error = 'No se pudo verificar la clave');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: const TextStyle(fontSize: 22, color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Usuario o clave',
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
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _busy
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Ingresar', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
