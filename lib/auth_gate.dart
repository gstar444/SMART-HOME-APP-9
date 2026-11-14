import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'home_controller.dart';
import 'login_page.dart';
import 'secure_storage.dart';
import 'settings.dart';
import 'username_page.dart';

/// लॉगिन जाँचता है। लॉगिन नहीं तो LoginPage।
/// लॉगिन है और इसी अकाउंट का यूज़रनेम नहीं तो UsernamePage, वरना होम।
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.settings,
    required this.store,
    required this.home,
  });

  final SettingsController settings;
  final SecureStore store;
  final HomeController home;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return _Gate(user: user, settings: settings, home: home, store: store);
      },
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate({
    required this.user,
    required this.settings,
    required this.home,
    required this.store,
  });

  final User user;
  final SettingsController settings;
  final HomeController home;
  final SecureStore store;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  late Future<String?> _usernameFuture;

  @override
  void initState() {
    super.initState();
    _usernameFuture = _load();
  }

  /// इसी uid के अकाउंट का यूज़रनेम, और MQTT जानकारी फ़ोन में लोड।
  Future<String?> _load() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();
    final data = snap.data();
    final name = data?['username'] as String?;
    if (data != null && data['host'] != null) {
      await widget.store.saveCloud(
        CloudConfig(
          host: (data['host'] as String?) ?? '',
          port: (data['port'] as num?)?.toInt() ?? 8883,
          homeId: (data['homeId'] as String?) ?? 'home',
          username: (data['username'] as String?) ?? '',
          password: (data['password'] as String?) ?? '',
        ),
      );
    }
    return (name == null || name.isEmpty) ? null : name;
  }

  void _reload() => setState(() => _usernameFuture = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _usernameFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return const Scaffold(
            body: Center(child: Text('डेटा नहीं मिला, ऐप फिर से खोलें')),
          );
        }
        if (snap.data == null) {
          return UsernamePage(user: widget.user, onDone: _reload);
        }
        return DashboardPage(settings: widget.settings, esp: widget.home);
      },
    );
  }
}
