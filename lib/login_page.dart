import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _bg = Color(0xFF121212);
const Color _fieldBg = Color(0xFF232129);
const Color _accent = Color(0xFFD0BCFF);
const Color _onAccent = Color(0xFF381E72);
const Color _muted = Color(0xFFCAC4D0);
const Color _text = Color(0xFFE6E1E5);
const Color _danger = Color(0xFFF2B8B5);

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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  int _tab = 0; // 0 = लॉगिन, 1 = अकाउंट बनाएँ
  int _method = 0; // लॉगिन में: 0 = ईमेल, 1 = फ़ोन
  int _signupStep = 0; // अकाउंट में: 0 = जानकारी, 1 = OTP
  String? _verificationId;
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    loadLoginLanguage();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _phone, _otp]) {
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
          return l.t('ईमेल या पासवर्ड गलत है', 'Wrong email or password');
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
        case 'invalid-phone-number':
          return l.t('फ़ोन नंबर सही नहीं है', 'Invalid phone number');
        case 'invalid-verification-code':
          return l.t('OTP गलत है', 'Wrong OTP');
        case 'credential-already-in-use':
          return l.t(
            'यह फ़ोन नंबर पहले से किसी अकाउंट से जुड़ा है',
            'This phone is already linked to an account',
          );
        case 'too-many-requests':
          return l.t(
            'बहुत कोशिशें हो गईं, थोड़ी देर बाद कोशिश करें',
            'Too many attempts, try again later',
          );
        case 'network-request-failed':
          return l.t('इंटरनेट जाँचें', 'Check your internet connection');
      }
    }
    if (e is FirebaseAuthException) return 'Error: ${e.code}';
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

  bool _validPhone(String v) => RegExp(r'^\+\d{10,15}$').hasMatch(v);

  Future<void> _loginEmail(_L l) async {
    if (!_email.text.contains('@') || _password.text.isEmpty) {
      _set(
        () => _error = l.t('ईमेल और पासवर्ड डालें', 'Enter email and password'),
      );
      return;
    }
    await _run(l, () async {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    });
  }

  Future<void> _forgot(_L l) async {
    if (!_email.text.contains('@')) {
      _set(() => _error = l.t('पहले ईमेल डालें', 'Enter your email first'));
      return;
    }
    await _run(l, () async {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _email.text.trim(),
      );
      _set(
        () => _info = l.t(
          'रीसेट लिंक ईमेल पर भेजा गया',
          'Reset link sent to your email',
        ),
      );
    });
  }

  Future<void> _sendOtp(_L l, {required bool signup}) async {
    final raw = _phone.text.trim().replaceAll(' ', '');
    final number = raw.startsWith('+') ? raw : '+91$raw';
    _phone.text = number;
    if (!_validPhone(number)) {
      _set(
        () => _error = l.t(
          'देश कोड के साथ नंबर लिखें, जैसे +919876543210',
          'Enter number with country code, e.g. +919876543210',
        ),
      );
      return;
    }
    _set(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        verificationCompleted: (_) {},
        verificationFailed: (e) => _set(() {
          _busy = false;
          _error = _msg(e, l);
        }),
        codeSent: (id, _) => _set(() {
          _verificationId = id;
          _busy = false;
          if (signup) _signupStep = 1;
          _info = l.t('OTP भेजा गया है', 'OTP sent');
        }),
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      _set(() {
        _busy = false;
        _error = _msg(e, l);
      });
    }
  }

  Future<void> _verifyPhoneLogin(_L l) async {
    final id = _verificationId;
    if (id == null) return;
    await _run(l, () async {
      await FirebaseAuth.instance.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: id,
          smsCode: _otp.text.trim(),
        ),
      );
    });
  }

  Future<void> _startSignup(_L l) async {
    if (_name.text.trim().isEmpty ||
        !_email.text.contains('@') ||
        _password.text.length < 6) {
      _set(
        () => _error = l.t(
          'नाम, ईमेल और 6+ अक्षर का पासवर्ड डालें',
          'Enter name, email and a password of 6+ characters',
        ),
      );
      return;
    }
    await _sendOtp(l, signup: true);
  }

  Future<void> _finishSignup(_L l) async {
    final id = _verificationId;
    if (id == null) return;
    await _run(l, () async {
      final auth = FirebaseAuth.instance;
      final phoneLogin = await auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: id,
          smsCode: _otp.text.trim(),
        ),
      );
      final user = phoneLogin.user;
      if (user == null) return;
      await user.linkWithCredential(
        EmailAuthProvider.credential(
          email: _email.text.trim(),
          password: _password.text,
        ),
      );
      await user.updateDisplayName(_name.text.trim());
    });
  }

  Future<void> _google(_L l) => _run(l, () async {
    final gs = GoogleSignIn.instance;
    await gs.initialize();
    final account = await gs.authenticate();
    await FirebaseAuth.instance.signInWithCredential(
      GoogleAuthProvider.credential(idToken: account.authentication.idToken),
    );
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
    String? prefix,
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
          prefixText: prefix,
          prefixStyle: const TextStyle(color: _text, fontSize: 15),
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

  List<Widget> _loginFields(_L l) {
    if (_method == 0) {
      return [
        _field(
          label: l.t('ईमेल', 'Email'),
          controller: _email,
          icon: Icons.mail_outline,
          type: TextInputType.emailAddress,
          hint: 'you@gmail.com',
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
            onPressed: _busy ? null : () => _forgot(l),
            child: Text(
              l.t('पासवर्ड भूल गए?', 'Forgot password?'),
              style: const TextStyle(color: _accent, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _primary(l.t('लॉगिन करें', 'Sign in'), () => _loginEmail(l)),
      ];
    }
    return [
      _field(
        label: l.t('फ़ोन नंबर (10 अंक)', 'Phone number (10 digits)'),
        controller: _phone,
        icon: Icons.phone_outlined,
        type: TextInputType.phone,
        hint: '9876543210',
        prefix: '+91 ',
      ),
      if (_verificationId != null)
        _field(
          label: 'OTP',
          controller: _otp,
          icon: Icons.sms_outlined,
          type: TextInputType.number,
        ),
      const SizedBox(height: 6),
      if (_verificationId == null)
        _primary(l.t('OTP भेजें', 'Send OTP'), () => _sendOtp(l, signup: false))
      else
        _primary(
          l.t('OTP से लॉगिन करें', 'Sign in with OTP'),
          () => _verifyPhoneLogin(l),
        ),
    ];
  }

  List<Widget> _signupFields(_L l) {
    if (_signupStep == 0) {
      return [
        _field(
          label: l.t('पूरा नाम', 'Full name'),
          controller: _name,
          icon: Icons.person_outline,
        ),
        _field(
          label: l.t('ईमेल', 'Email'),
          controller: _email,
          icon: Icons.mail_outline,
          type: TextInputType.emailAddress,
          hint: 'you@gmail.com',
        ),
        _field(
          label: l.t('फ़ोन नंबर', 'Phone number'),
          controller: _phone,
          icon: Icons.phone_outlined,
          type: TextInputType.phone,
          hint: '+919876543210',
        ),
        _field(
          label: l.t('पासवर्ड बनाएँ', 'Create password'),
          controller: _password,
          icon: Icons.lock_outline,
          password: true,
        ),
        const SizedBox(height: 6),
        _primary(l.t('OTP भेजें', 'Send OTP'), () => _startSignup(l)),
      ];
    }
    return [
      Text(
        l.t(
          'फ़ोन पर आया 6 अंकों का OTP डालें',
          'Enter the 6-digit OTP sent to your phone',
        ),
        style: const TextStyle(color: _muted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      _field(
        label: 'OTP',
        controller: _otp,
        icon: Icons.sms_outlined,
        type: TextInputType.number,
      ),
      _primary(
        l.t('सत्यापित करें और बनाएँ', 'Verify and create account'),
        () => _finishSignup(l),
      ),
      TextButton(
        onPressed: _busy
            ? null
            : () => _set(() {
                _signupStep = 0;
                _otp.clear();
              }),
        child: Text(
          l.t('जानकारी बदलें', 'Edit details'),
          style: const TextStyle(color: _accent),
        ),
      ),
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
                    _signupStep = 0;
                    _verificationId = null;
                  }),
                ),
                const SizedBox(height: 18),
                if (_tab == 0) ...[
                  _tabs(
                    [l.t('ईमेल', 'Email'), l.t('फ़ोन', 'Phone')],
                    _method,
                    (i) => _set(() {
                      _method = i;
                      _error = null;
                      _verificationId = null;
                    }),
                  ),
                  const SizedBox(height: 18),
                  ..._loginFields(l),
                ] else
                  ..._signupFields(l),
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
                    style: const TextStyle(
                      color: Color(0xFF9FD8A6),
                      fontSize: 13,
                    ),
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
