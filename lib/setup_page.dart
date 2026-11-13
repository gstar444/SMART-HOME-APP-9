import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'cloud_store.dart';
import 'dashboard_page.dart';
import 'home_controller.dart';
import 'secure_storage.dart';
import 'settings.dart';

/// पहली बार लॉगिन के बाद एक बार भरने वाली सेटिंग (MQTT और ESP32 IP)।
class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.store, required this.settings});

  final SecureStore store;
  final SettingsController settings;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '8883');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _home = TextEditingController(text: 'home');
  final _ip = TextEditingController(text: 'http://192.168.1.12/');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_host, _port, _user, _pass, _home, _ip]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final host = _host.text.trim();
    final user = _user.text.trim();
    final pass = _pass.text;
    if (host.isEmpty ||
        user.isEmpty ||
        pass.isEmpty ||
        _ip.text.trim().isEmpty) {
      setState(() => _error = 'सभी जानकारी भरें');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CloudStore.saveSetup(
        host: host,
        port: int.tryParse(_port.text.trim()) ?? 8883,
        homeId: _home.text.trim().isEmpty ? 'home' : _home.text.trim(),
        username: user,
        password: pass,
        espUrl: _ip.text.trim(),
        store: widget.store,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardPage(
            settings: widget.settings,
            esp: context.read<HomeController>(),
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'सेव नहीं हुआ, फिर कोशिश करें');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(String label, TextEditingController c, {bool obscure = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('सेटअप')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('एक बार भरें। अगली बार लॉगिन के बाद अपने आप लोड होगा।'),
          const SizedBox(height: 16),
          _f('MQTT host', _host),
          _f('Port', _port),
          _f('MQTT username', _user),
          _f('MQTT password', _pass, obscure: true),
          _f('Home ID', _home),
          _f('ESP32 IP (घर पर)', _ip),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: const Text('सेव करें'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
