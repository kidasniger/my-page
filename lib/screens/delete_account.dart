import 'package:flutter/material.dart';
import '../core/account_delete.dart';
import '../core/auth.dart';
import '../core/palette.dart';
import '../ui/forms.dart' show kConfirm;
import '../ui/shell.dart' show SubPage;

const _kDanger = Color(0xFFE5484D);

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _pw = TextEditingController();
  bool _hide = true;
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _err = msg;
    });
  }

  Future<void> _delete() async {
    if (_busy) return;
    if (Auth.isEmail && _pw.text.isEmpty) {
      setState(() => _err = 'Saisissez votre mot de passe pour confirmer.');
      return;
    }
    final nav = Navigator.of(context);
    final ok = await kConfirm(
      context,
      'Supprimer définitivement votre compte et toutes vos données ? '
      'Cette action est irréversible.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });

    String? e;
    if (Auth.isGoogle) {
      e = await Auth.reauthGoogle();
    } else if (Auth.isEmail) {
      e = await Auth.reauthEmail(_pw.text);
    } else {
      e = 'Mode de connexion non reconnu. Déconnectez-vous puis reconnectez-vous.';
    }
    if (e != null) return _fail(e);

    e = await AccountData.deleteAll();
    if (e != null) return _fail(e);

    e = await Auth.deleteAccount();
    if (e != null) return _fail(e);

    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final style = TextStyle(color: c.ink, fontSize: 15, height: 1.45);
    return SubPage(
      'Supprimer mon compte',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Cette action supprime votre compte My Page et toutes vos '
            'données : Pages connectées, messages, statistiques, profil, '
            'questions et file de publication.',
            style: style,
          ),
          const SizedBox(height: 12),
          Text(
            'Pour votre sécurité, vous devez confirmer votre identité '
            'avant la suppression.',
            style: style,
          ),
          const SizedBox(height: 20),
          if (Auth.isEmail)
            TextField(
              controller: _pw,
              obscureText: _hide,
              enabled: !_busy,
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
          if (_err != null) ...[
            const SizedBox(height: 12),
            Text(_err!,
                style: const TextStyle(color: _kDanger, fontSize: 14)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _busy ? null : _delete,
              style: FilledButton.styleFrom(
                backgroundColor: _kDanger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Supprimer définitivement mon compte'),
            ),
          ),
        ],
      ),
    );
  }
}
