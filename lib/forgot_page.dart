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
const Color _ok = Color(0xFF9FD8A6);

/// पासवर्ड भूल गए: सिर्फ़ ईमेल या यूज़रनेम माँगता है और रीसेट लिंक ईमेल पर भेजता है।
class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});

  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<String?> _emailFor(String input) async {
    if (input.contains('@')) return input;
    final snap = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(input.toLowerCase())
        .get();
    return snap.data()?['email'] as String?;
  }

  Future<void> _send() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'ईमेल या यूज़रनेम डालें');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = await _emailFor(input);
      if (!mounted) return;
      if (email == null) {
        setState(() => _error = 'यह यूज़रनेम नहीं मिला');
        return;
      }
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() {
          _sent = true;
          _sentTo = email;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'लिंक नहीं गया, फिर कोशिश करें');
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
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 28),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _text),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Text(
                  'पासवर्ड भूल गए?',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'अपना ईमेल या यूज़रनेम डालें। हम उस ईमेल पर पासवर्ड बदलने का लिंक भेजेंगे।',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.6),
              ),
            ),
            const SizedBox(height: 22),
            if (!_sent) ...[
              TextField(
                controller: _ctrl,
                enabled: !_busy,
                style: const TextStyle(color: _text, fontSize: 15),
                decoration: InputDecoration(
                  labelText: 'ईमेल या यूज़रनेम',
                  labelStyle: const TextStyle(color: _muted),
                  floatingLabelStyle: const TextStyle(color: _accent),
                  prefixIcon: const Icon(Icons.mail_outline, color: _muted),
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
              const SizedBox(height: 16),
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
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _onAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'लिंक भेजें',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2A3E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: _ok,
                      size: 36,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'लिंक भेज दिया गया',
                      style: TextStyle(
                        color: _ok,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_sentTo पर लिंक भेजा गया है। ईमेल खोलकर लिंक पर क्लिक करें। न मिले तो Spam फ़ोल्डर देखें।',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : _send,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _text,
                    side: const BorderSide(color: Color(0xFF938F99)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('लिंक फिर से भेजें'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'लॉगिन पर वापस जाएँ',
                  style: TextStyle(color: _accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
