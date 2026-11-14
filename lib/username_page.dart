import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _bg = Color(0xFF121212);
const Color _fieldBg = Color(0xFF232129);
const Color _accent = Color(0xFFD0BCFF);
const Color _onAccent = Color(0xFF381E72);
const Color _muted = Color(0xFFCAC4D0);
const Color _text = Color(0xFFE6E1E5);
const Color _danger = Color(0xFFF2B8B5);

final RegExp _usernameShape = RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)*$');

/// यूज़रनेम की जाँच। सही हो तो null, वरना संदेश।
String? usernameError(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.length < 3 || v.length > 20) return '3 से 20 अक्षर लिखें';
  if (!_usernameShape.hasMatch(v)) {
    return 'सिर्फ़ a-z, 0-9, _ और डॉट (.) चलेंगे; शुरू या आख़िर में डॉट नहीं';
  }
  return null;
}

class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key, required this.user, required this.onDone});

  final User user;
  final VoidCallback onDone;

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _ctrl.text.trim().toLowerCase();
    final err = usernameError(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('usernames').doc(v);
      final existing = await ref.get();
      if (!mounted) return;
      if (existing.exists) {
        setState(() => _error = 'यह यूज़रनेम पहले से किसी और का है');
        return;
      }
      await ref.set({'uid': widget.user.uid, 'email': widget.user.email});
      await db.collection('users').doc(widget.user.uid).set({
        'username': v,
      }, SetOptions(merge: true));
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _error = 'सेव नहीं हुआ, फिर कोशिश करें');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 70,
                  height: 70,
                  cacheWidth: 210,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'यूज़रनेम बनाएँ',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'लॉगिन के लिए एक यूज़रनेम चुनें।',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              enabled: !_busy,
              style: const TextStyle(color: _text, fontSize: 15),
              decoration: InputDecoration(
                labelText: 'यूज़रनेम',
                hintText: 'ashish.home',
                labelStyle: const TextStyle(color: _muted),
                floatingLabelStyle: const TextStyle(color: _accent),
                prefixIcon: const Icon(Icons.alternate_email, color: _muted),
                filled: true,
                fillColor: _fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: _accent, width: 1.6),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• 3 से 20 अक्षर\n• अक्षर (a-z), अंक (0-9), डॉट (.) और _\n• शुरू या आख़िर में डॉट नहीं',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _danger, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: _onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _onAccent,
                        ),
                      )
                    : const Text(
                        'यूज़रनेम सेव करें',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => FirebaseAuth.instance.signOut(),
                child: const Text('लॉग आउट', style: TextStyle(color: _muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
