import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cloud_store.dart';
import 'dashboard_page.dart';
import 'home_controller.dart';
import 'login_page.dart';
import 'secure_storage.dart';
import 'settings.dart';
import 'setup_page.dart';

/// लॉगिन जाँचता है। लॉगिन न हो तो LoginPage, लॉगिन हो तो सेव की हुई सेटिंग से होम।
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
        if (snap.data == null) return const LoginPage();
        return DashboardPage(settings: settings, esp: home);
      },
    );
  }
}

class _Loaded extends StatefulWidget {
  const _Loaded({
    required this.settings,
    required this.store,
    required this.home,
  });

  final SettingsController settings;
  final SecureStore store;
  final HomeController home;

  @override
  State<_Loaded> createState() => _LoadedState();
}

class _LoadedState extends State<_Loaded> {
  late final Future<CloudSetup?> _future = CloudStore.loadSetup();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CloudSetup?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final setup = snap.data;
        if (setup == null) {
          return SetupPage(store: widget.store, settings: widget.settings);
        }
        return DashboardPage(settings: widget.settings, esp: widget.home);
      },
    );
  }
}
