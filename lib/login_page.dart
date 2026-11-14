import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'forgot_page.dart';

const Color _bg = Color(0xFF121212);
const Color _fieldBg = Color(0xFF232129);
const Color _accent = Color(0xFFD0BCFF);
const Color _onAccent = Color(0xFF381E72);
const Color _muted = Color(0xFFCAC4D0);
const Color _text = Color(0xFFE6E1E5);
const Color _danger = Color(0xFFF2B8B5);
const Color _ok = Color(0xFF9FD8A6);

/// भाषा (true = हिंदी)। फ़ोन में सेव रहती है।
final ValueNotifier<bool> loginHindi = ValueNotifier<bool>(true);

Future<void> loadLoginLanguage() async {
  final p = await SharedPreferences.getInstance();
  loginHindi.value = p.getBool('login_hindi') ?? true;
}

Future<void> setLoginLanguage(bool hindi) async {
  loginHindi.value = hindi;
  final p = await SharedPreferences.getInstance();
  await p.setBool('login_hindi', hindi);
}

class _L {
  const _L(this.h);
  final bool h;
  String t(String hi, String en) => h ? hi : en;
}

final RegExp _usernameRe = RegExp(r'^[a-z0-9_]{3,20}$');

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _loginId = TextEditingController();

  int _tab = 0; // 0 = लॉगिन, 1 = अकाउंट बनाएँ
  bool _busy = false;
  bool _obscure = true;
  bool _awaitingVerify = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    loadLoginLanguage();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _username, _password, _loginId]) {
      c.dispose();
    }
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  String _msg(Object e, _L l) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return l.t(
            'ईमेल/यूज़रनेम या पासवर्ड गलत है',
            'Wrong email/username or password',
          );
        case 'email-already-in-use':
          return l.t(
            'यह ईमेल पहले से बना है',
            'This email is already registered',
          );
        case 'invalid-email':
          return l.t('ईमेल सही नहीं है', 'Invalid email');
        case 'weak-password':
          return l.t(
            'पासवर्ड कम से कम 6 अक्षर का हो',
            'Password must be at least 6 characters',
          );
        case 'too-many-requests':
          return l.t(
            'बहुत कोशिशें हो गईं, थोड़ी देर बाद कोशिश करें',
            'Too many attempts, try again later',
          );
        case 'network-request-failed':
          return l.t('इंटरनेट जाँचें', 'Check your internet connection');
      }
      if (e.code == 'account-not-found') {
        return 'इस ईमेल से अकाउंट नहीं मिला';
      }
      return 'Error: ${e.code}';
    }
    return 'Error: $e';
  }

  Future<void> _run(_L l, Future<void> Function() action) async {
    _set(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } catch (e) {
      _set(() => _error = _msg(e, l));
    } finally {
      _set(() => _busy = false);
    }
  }

  /// ईमेल है तो वही, वरना यूज़रनेम से ईमेल ढूँढें।
  Future<String?> _emailFor(String input) async {
    final v = input.trim();
    if (v.contains('@')) return v;
    final snap = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(v.toLowerCase())
        .get();
    return snap.data()?['email'] as String?;
  }

  Future<void> _login(_L l) async {
    if (_loginId.text.trim().isEmpty || _password.text.isEmpty) {
      _set(
        () => _error = l.t(
          'यूज़रनेम/ईमेल और पासवर्ड डालें',
          'Enter username/email and password',
        ),
      );
      return;
    }
    await _run(l, () async {
      final email = await _emailFor(_loginId.text);
      if (email == null) {
        throw FirebaseAuthException(code: 'user-not-found');
      }
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      final user = cred.user;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        _set(() {
          _awaitingVerify = true;
          _info = l.t(
            'ईमेल verify नहीं है। लिंक फिर से भेजा गया है।',
            'Email not verified. We sent the link again.',
          );
        });
      }
    });
  }

  Future<void> _signup(_L l) async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final username = _username.text.trim().toLowerCase();
    if (name.isEmpty || !email.contains('@') || _password.text.length < 6) {
      _set(
        () => _error = l.t(
          'नाम, ईमेल और 6+ अक्षर का पासवर्ड डालें',
          'Enter name, email and a password of 6+ characters',
        ),
      );
      return;
    }
    if (!_usernameRe.hasMatch(username)) {
      _set(
        () => _error = l.t(
          'यूज़रनेम में 3-20 अक्षर: a-z, 0-9, _',
          'Username: 3-20 chars, a-z, 0-9, _ only',
        ),
      );
      return;
    }
    await _run(l, () async {
      final taken =
          (await FirebaseFirestore.instance
                  .collection('usernames')
                  .doc(username)
                  .get())
              .exists;
      if (taken) {
        throw StateError('username-taken');
      }
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      final user = cred.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(username)
            .set({'uid': user.uid, 'email': email});
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': username,
        }, SetOptions(merge: true));
        await user.sendEmailVerification();
      }
      await FirebaseAuth.instance.signOut();
      _set(() {
        _awaitingVerify = true;
        _info = l.t(
          'ईमेल पर verification लिंक भेजा गया है। लिंक पर क्लिक करें, फिर "मैंने verify कर लिया" दबाएँ।',
          'A verification link was sent to your email. Click it, then press "I have verified".',
        );
      });
    }).catchError((e) {
      if (e is StateError && e.message == 'username-taken') {
        _set(
          () => _error = l.t(
            'यह यूज़रनेम पहले से लिया हुआ है',
            'This username is already taken',
          ),
        );
      }
    });
  }

  Future<void> _checkVerified(_L l) async {
    await _run(l, () async {
      final email = _email.text.trim();
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      await cred.user?.reload();
      if (cred.user?.emailVerified ?? false) {
        _set(() {
          _awaitingVerify = false;
          _info = null;
        });
      } else {
        await FirebaseAuth.instance.signOut();
        _set(
          () => _error = l.t(
            'अभी verify नहीं हुआ। लिंक पर क्लिक करें।',
            'Not verified yet. Please click the link.',
          ),
        );
      }
    });
  }

  Future<void> _google(_L l) => _run(l, () async {
    final gs = GoogleSignIn.instance;
    await gs.initialize();
    final account = await gs.authenticate();
    final cred = await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
    final user = cred.user;
    final email = user?.email;
    bool registered = false;
    if (email != null) {
      final byEmail = await FirebaseFirestore.instance
          .collection('usernames')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      registered = byEmail.docs.isNotEmpty;
    }
    if (!registered) {
      await FirebaseAuth.instance.signOut();
      throw FirebaseAuthException(code: 'account-not-found');
    }
  });

  Widget _tabs(List<String> labels, int selected, void Function(int) onPick) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == selected ? _onAccent : _muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? type,
    bool password = false,
    String? hint,
  }) {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !_busy,
        keyboardType: type,
        obscureText: password && _obscure,
        style: const TextStyle(color: _text, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _muted),
          floatingLabelStyle: const TextStyle(color: _accent),
          hintStyle: const TextStyle(color: Color(0xFF6F6A78)),
          prefixIcon: Icon(icon, color: _muted),
          suffixIcon: password
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: _muted,
                  ),
                  onPressed: () => _set(() => _obscure = !_obscure),
                )
              : null,
          filled: true,
          fillColor: _fieldBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: border(Colors.transparent, 0),
          enabledBorder: border(Colors.transparent, 0),
          focusedBorder: border(_accent, 1.6),
        ),
      ),
    );
  }

  Widget _primary(String text, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: _onAccent,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
  );

  List<Widget> _loginFields(_L l) => [
    _field(
      label: l.t('यूज़रनेम या ईमेल', 'Username or email'),
      controller: _loginId,
      icon: Icons.person_outline,
      type: TextInputType.emailAddress,
    ),
    _field(
      label: l.t('पासवर्ड', 'Password'),
      controller: _password,
      icon: Icons.lock_outline,
      password: true,
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _busy
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ForgotPage()),
              ),
        child: Text(
          l.t('पासवर्ड भूल गए?', 'Forgot password?'),
          style: const TextStyle(color: _accent, fontSize: 13),
        ),
      ),
    ),
    const SizedBox(height: 6),
    _primary(l.t('लॉगिन करें', 'Sign in'), () => _login(l)),
  ];

  List<Widget> _signupFields(_L l) {
    if (_awaitingVerify) {
      return [
        Text(
          l.t(
            'ईमेल पर लिंक भेजा गया है। लिंक पर क्लिक करके यहाँ लौटें।',
            'We sent a link to your email. Click it, then come back here.',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        _primary(
          l.t('मैंने verify कर लिया', 'I have verified'),
          () => _checkVerified(l),
        ),
      ];
    }
    return [
      _field(
        label: l.t('पूरा नाम', 'Full name'),
        controller: _name,
        icon: Icons.badge_outlined,
      ),
      _field(
        label: l.t('ईमेल', 'Email'),
        controller: _email,
        icon: Icons.mail_outline,
        type: TextInputType.emailAddress,
        hint: 'you@gmail.com',
      ),
      _field(
        label: l.t('यूज़रनेम', 'Username'),
        controller: _username,
        icon: Icons.alternate_email,
        hint: 'ashish_home',
      ),
      _field(
        label: l.t('पासवर्ड बनाएँ', 'Create password'),
        controller: _password,
        icon: Icons.lock_outline,
        password: true,
      ),
      const SizedBox(height: 6),
      _primary(l.t('अकाउंट बनाएँ', 'Create account'), () => _signup(l)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: loginHindi,
      builder: (context, hindi, _) {
        final l = _L(hindi);
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            actions: [
              TextButton(
                onPressed: () => setLoginLanguage(!hindi),
                child: Text(
                  hindi ? 'English' : 'हिंदी',
                  style: const TextStyle(color: _muted),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 84,
                      height: 84,
                      cacheWidth: 252,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'GSTAR HOME',
                    style: TextStyle(
                      color: _text,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    l.t(
                      'अपने घर को कहीं से भी नियंत्रित करें',
                      'Control your home from anywhere',
                    ),
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 26),
                _tabs(
                  [
                    l.t('लॉगिन', 'Sign in'),
                    l.t('अकाउंट बनाएँ', 'Create account'),
                  ],
                  _tab,
                  (i) => _set(() {
                    _tab = i;
                    _error = null;
                    _info = null;
                    _awaitingVerify = false;
                  }),
                ),
                const SizedBox(height: 18),
                ...(_tab == 0 ? _loginFields(l) : _signupFields(l)),
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const Center(
                    child: CircularProgressIndicator(color: _accent),
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _ok, fontSize: 13),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF49454F))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l.t('या', 'or'),
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF49454F))),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _google(l),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _text,
                      side: const BorderSide(color: Color(0xFF938F99)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text(
                      l.t('Google से जारी रखें', 'Continue with Google'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
