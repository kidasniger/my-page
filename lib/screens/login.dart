import 'package:flutter/material.dart';

import '../core/auth.dart';
import '../core/palette.dart';
import '../ui/common.dart';

/// Connexion et création de compte My Page.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _signup = false, _busy = false, _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() f, {String? ok}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final err = await f();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      if (ok != null) kToast(context, ok);
    } else if (err.isNotEmpty) {
      kToast(context, err, bad: true);
    }
  }

  void _submit() {
    final mail = _email.text.trim();
    if (!mail.contains('@')) {
      kToast(context, 'Saisissez une adresse e-mail valide.', bad: true);
      return;
    }
    if (_pw.text.length < 6) {
      kToast(context, 'Le mot de passe fait 6 caractères minimum.', bad: true);
      return;
    }
    _run(() => _signup
        ? Auth.signUpEmail(mail, _pw.text)
        : Auth.signInEmail(mail, _pw.text));
  }

  void _forgot() {
    final mail = _email.text.trim();
    if (!mail.contains('@')) {
      kToast(context, "Saisissez d'abord votre e-mail.", bad: true);
      return;
    }
    _run(() => Auth.resetPassword(mail),
        ok: 'E-mail de réinitialisation envoyé.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(Icons.check_rounded,
                          size: 44, color: c.onAccent),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('My Page',
                      textAlign: TextAlign.center,
                      style: T.hero(c).copyWith(color: c.ink, fontSize: 30)),
                  const SizedBox(height: 4),
                  Text('Gérez votre Page, simplement',
                      textAlign: TextAlign.center, style: T.caption(c)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: _hide,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      suffixIcon: IconButton(
                        icon: Icon(_hide
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  KBtn(_signup ? 'Créer mon compte' : 'Me connecter',
                      busy: _busy, onTap: _submit),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _run(Auth.signInGoogle),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.ink,
                        side: BorderSide(color: c.line),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google.png',
                            width: 22,
                            height: 22,
                            cacheWidth: 66,
                            excludeFromSemantics: true,
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: Text(
                              'Continuer avec Google',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _busy ? null : () => setState(() => _signup = !_signup),
                    child: Text(_signup
                        ? "J'ai déjà un compte"
                        : "Je n'ai pas de compte"),
                  ),
                  if (!_signup)
                    TextButton(
                      onPressed: _busy ? null : _forgot,
                      child: const Text('Mot de passe oublié'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
