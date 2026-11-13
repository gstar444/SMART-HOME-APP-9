import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _accent = Color(0xFF7C5CF0);
const Color _bg = Color(0xFF0B1019);
const Color _field = Color(0xFF141C2C);
const Color _line = Color(0xFF263150);
const Color _muted = Color(0xFF8FA0BD);

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
        case 'too-many-requests':
          return l.t(
            'बहुत कोशिशें हो गईं, थोड़ी देर बाद कोशिश करें',
            'Too many attempts, try again later',
          );
        case 'network-request-failed':
          return l.t('इंटरनेट जाँचें', 'Check your internet connection');
      }
    }
    return l.t(
      'कुछ गड़बड़ हुई, फिर कोशिश करें',
      'Something went wrong, please try again',
    );
  }

  Future<void> _loginEmail(_L l) async {
    final email = _email.text.trim();
    final pass = _password.text;
    if (!email.contains('@') || pass.isEmpty) {
      _set(
        () => _error = l.t('ईमेल और पासवर्ड डालें', 'Enter email and password'),
      );
      return;
    }
    _set(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );
    } catch (e) {
      _set(() => _error = _msg(e, l));
    } finally {
      _set(() => _busy = false);
    }
  }

  Future<void> _forgot(_L l) async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      _set(() => _error = l.t('पहले ईमेल डालें', 'Enter your email first'));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _set(
        () => _info = l.t(
          'रीसेट लिंक आपके ईमेल पर भेजा गया',
          'Reset link sent to your email',
        ),
      );
    } catch (e) {
      _set(() => _error = _msg(e, l));
    }
  }

  Future<void> _sendOtp(_L l, {required bool signup}) async {
    final number = _phone.text.trim();
    if (!RegExp(r'^\+\d{10,15}$').hasMatch(number)) {
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
        phoneNumber: number,
        verificationCompleted: (cred) async {
          if (!signup) {
            await FirebaseAuth.instance.signInWithCredential(cred);
          }
        },
        verificationFailed: (e) => _set(() {
          _busy = false;
          _error = _msg(e, l);
        }),
        codeSent: (id, _) => _set(() {
          _verificationId = id;
          _busy = false;
          if (signup) _signupStep = 1;
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

  Future<void> _verifyLoginOtp(_L l) async {
    final id = _verificationId;
    if (id == null) return;
    _set(() {
      _busy = true;
      _error = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: id,
        smsCode: _otp.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
    } catch (e) {
      _set(() => _error = _msg(e, l));
    } finally {
      _set(() => _busy = false);
    }
  }

  Future<void> _createAccount(_L l) async {
    final id = _verificationId;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pass = _password.text;
    if (id == null) return;
    if (name.isEmpty || !email.contains('@') || pass.length < 6) {
      _set(
        () => _error = l.t(
          'नाम, ईमेल और 6+ अक्षर का पासवर्ड डालें',
          'Enter name, email and a password of 6+ characters',
        ),
      );
      return;
    }
    _set(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final user = result.user;
      if (user != null) {
        await user.updateDisplayName(name);
        await user.linkWithCredential(
          PhoneAuthProvider.credential(
            verificationId: id,
            smsCode: _otp.text.trim(),
          ),
        );
      }
    } catch (e) {
      _set(() => _error = _msg(e, l));
    } finally {
      _set(() => _busy = false);
    }
  }

  Future<void> _google(_L l) async {
    _set(() {
      _busy = true;
      _error = null;
    });
    try {
      final gs = GoogleSignIn.instance;
      await gs.initialize();
      final account = await gs.authenticate();
      final idToken = account.authentication.idToken;
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
    } catch (e) {
      _set(
        () => _error = l.t('Google लॉगिन नहीं हुआ', 'Google sign-in failed'),
      );
    } finally {
      _set(() => _busy = false);
    }
  }

  void _switchTab(int i) => _set(() {
    _tab = i;
    _error = null;
    _info = null;
    _signupStep = 0;
    _verificationId = null;
  });

  Widget _seg(List<String> labels, int selected, void Function(int) onPick) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onPick(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: i == selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: i == selected ? Colors.white : _muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController c,
    bool obscure = false,
    TextInputType? type,
    String? hint,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          enabled: !_busy,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: _field,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: border(_line),
            enabledBorder: border(_line),
            focusedBorder: border(_accent),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _primary(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  List<Widget> _loginBody(_L l) {
    if (_method == 0) {
      return [
        _input(
          label: l.t('ईमेल', 'Email'),
          c: _email,
          type: TextInputType.emailAddress,
          hint: 'you@gmail.com',
        ),
        _input(label: l.t('पासवर्ड', 'Password'), c: _password, obscure: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _forgot(l),
            child: Text(
              l.t('पासवर्ड भूल गए?', 'Forgot password?'),
              style: const TextStyle(color: Color(0xFFA893FF), fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _primary(l.t('लॉगिन करें', 'Login'), () => _loginEmail(l)),
      ];
    }
    return [
      _input(
        label: l.t('फ़ोन नंबर', 'Phone number'),
        c: _phone,
        type: TextInputType.phone,
        hint: '+919876543210',
      ),
      if (_verificationId != null) ...[
        _input(
          label: l.t('OTP डालें', 'Enter OTP'),
          c: _otp,
          type: TextInputType.number,
        ),
        _primary(
          l.t('सत्यापित करके लॉगिन', 'Verify and login'),
          () => _verifyLoginOtp(l),
        ),
      ] else
        _primary(
          l.t('OTP भेजें', 'Send OTP'),
          () => _sendOtp(l, signup: false),
        ),
      const SizedBox(height: 10),
      Text(
        l.t('फ़ोन से लॉगिन OTP से होगा', 'Phone login uses OTP'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: _muted),
      ),
    ];
  }

  List<Widget> _signupBody(_L l) {
    if (_signupStep == 0) {
      return [
        _input(label: l.t('पूरा नाम', 'Full name'), c: _name),
        _input(
          label: l.t('ईमेल', 'Email'),
          c: _email,
          type: TextInputType.emailAddress,
          hint: 'you@gmail.com',
        ),
        _input(
          label: l.t('फ़ोन नंबर (+91...)', 'Phone (+91...)'),
          c: _phone,
          type: TextInputType.phone,
          hint: '+919876543210',
        ),
        _input(
          label: l.t('पासवर्ड बनाएँ', 'Create password'),
          c: _password,
          obscure: true,
        ),
        const SizedBox(height: 4),
        _primary(l.t('OTP भेजें', 'Send OTP'), () => _sendOtp(l, signup: true)),
      ];
    }
    return [
      Text(
        l.t('फ़ोन पर आया OTP डालें', 'Enter the OTP sent to your phone'),
        style: const TextStyle(fontSize: 13, color: _muted),
      ),
      const SizedBox(height: 10),
      _input(label: 'OTP', c: _otp, type: TextInputType.number),
      _primary(
        l.t('सत्यापित करें और बनाएँ', 'Verify and create account'),
        () => _createAccount(l),
      ),
      TextButton(
        onPressed: _busy ? null : () => _sendOtp(l, signup: true),
        child: Text(
          l.t('OTP फिर भेजें', 'Resend OTP'),
          style: const TextStyle(color: Color(0xFFA893FF)),
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
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 24),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 180,
                    child: _seg(
                      ['हिंदी', 'English'],
                      hindi ? 0 : 1,
                      (i) => setLoginLanguage(i == 0),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Center(
                  child: Text(
                    'GSTAR HOME',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
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
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: _seg(
                    [
                      l.t('लॉगिन', 'Login'),
                      l.t('अकाउंट बनाएँ', 'Create account'),
                    ],
                    _tab,
                    _switchTab,
                  ),
                ),
                const SizedBox(height: 16),
                if (_tab == 0) ...[
                  SizedBox(
                    width: double.infinity,
                    child: _seg(
                      [l.t('ईमेल', 'Email'), l.t('फ़ोन', 'Phone')],
                      _method,
                      (i) => _set(() {
                        _method = i;
                        _error = null;
                        _verificationId = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...(_tab == 0 ? _loginBody(l) : _signupBody(l)),
                if (_busy) ...[
                  const SizedBox(height: 14),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF34C77B),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(child: Divider(color: _line)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        l.t('या', 'or'),
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ),
                    const Expanded(child: Divider(color: _line)),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _google(l),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1F2937),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l.t('Google से जारी रखें', 'Continue with Google'),
                      style: const TextStyle(fontWeight: FontWeight.w500),
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
