import 'package:flutter/material.dart';

import '../core/api.dart' show Api;
import '../core/bot_profile.dart';
import '../core/palette.dart';
import '../ui/common.dart';
import '../ui/forms.dart';
import '../ui/shell.dart' show SubPage;

class _Q {
  final String champ, texte, aide;
  final List<(String, String)> choix;
  const _Q(this.champ, this.texte, this.aide, [this.choix = const []]);
}

const List<_Q> _questions = [
  _Q('activite', "Quelle est l'activité de votre Page ?",
      'Une phrase. Exemple : vente de pagnes à Niamey.'),
  _Q('ton', 'Quel ton le bot doit-il utiliser ?',
      'Vous pourrez le changer à tout moment.', [
    ('chaleureux', 'Chaleureux'),
    ('neutre', 'Neutre'),
    ('direct', 'Direct'),
  ]),
  _Q('public', "À qui s'adresse votre Page ?",
      'Exemple : jeunes femmes de Niamey.'),
  _Q('horaires', 'Quels sont vos horaires ?',
      'Exemple : du lundi au samedi, de 8 h à 19 h.'),
  _Q('offres', 'Quelle est votre offre principale, avec son prix ?',
      'Exemple : pagne wax 6 yards, 7 500 FCFA.'),
  _Q('eviter', 'Sur quel sujet le bot ne doit-il jamais répondre ?',
      'Exemple : politique.'),
  _Q('langues', 'Dans quelle langue le bot doit-il répondre ?', '', [
    ('fr', 'Français'),
    ('en', 'Anglais'),
    ('ha', 'Haoussa'),
    ('dje', 'Zarma'),
  ]),
  _Q('reponsePrix', 'Que doit répondre le bot quand on demande un prix ?',
      'Exemple : écrivez-nous en message privé pour les prix.'),
];

/// Questionnaire de départ : 8 questions fixes, sans IA. Chaque réponse est
/// enregistrée tout de suite ; chaque question peut être passée.
/// Renvoie true quand l'utilisateur arrive au bout.
class BotQuestionnairePage extends StatefulWidget {
  final String pageId;
  final BotProfil profil;
  const BotQuestionnairePage({
    super.key,
    required this.pageId,
    required this.profil,
  });
  @override
  State<BotQuestionnairePage> createState() => _BotQuestionnaireState();
}

class _BotQuestionnaireState extends State<BotQuestionnairePage> {
  int _i = 0;
  bool _busy = false;
  String _choix = '';
  final _texte = TextEditingController();
  late BotProfil _profil = widget.profil;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  void _suivant() {
    if (_i >= _questions.length - 1) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _i++;
      _choix = '';
      _texte.clear();
    });
  }

  Future<void> _valider() async {
    final q = _questions[_i];
    final reponse = q.choix.isEmpty ? _texte.text.trim() : _choix;
    if (reponse.isEmpty) {
      kToast(context, q.choix.isEmpty
          ? 'Écrivez une réponse, ou passez.'
          : 'Choisissez une réponse, ou passez.');
      return;
    }
    final v = BotProfil.valeur(q.champ, reponse, _profil.data);
    if (v == null) return;
    setState(() => _busy = true);
    try {
      await BotData.saveProfil(widget.pageId, _profil, {q.champ: v});
      _profil = BotProfil({..._profil.data, q.champ: v});
      if (!mounted) return;
      setState(() => _busy = false);
      _suivant();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      kToast(context, Api.hint(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final q = _questions[_i];
    final dernier = _i == _questions.length - 1;
    return SubPage(
      'Configurer mon bot',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('QUESTION ${_i + 1} SUR ${_questions.length}', style: T.micro(c)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (_i + 1) / _questions.length,
              minHeight: 4,
              backgroundColor: c.line,
              valueColor: AlwaysStoppedAnimation(c.ink),
            ),
          ),
          const SizedBox(height: 22),
          Text(q.texte, style: T.title(c).copyWith(fontSize: 19)),
          if (q.aide.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(q.aide, style: T.caption(c)),
          ],
          const SizedBox(height: 16),
          if (q.choix.isEmpty)
            KEdit(
              key: ValueKey(q.champ),
              controller: _texte,
              hint: 'Votre réponse',
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
            )
          else
            ...[
              for (final (val, label) in q.choix) ...[
                _Choix(
                  label,
                  selected: _choix == val,
                  onTap: () => setState(() => _choix = val),
                ),
                const SizedBox(height: 8),
              ],
            ],
          const SizedBox(height: 20),
          KBtn(dernier ? 'Terminer' : 'Suivant', busy: _busy, onTap: _valider),
          const SizedBox(height: 10),
          KBtnGhost('Passer', onTap: _busy ? null : _suivant),
        ],
      ),
    );
  }
}

class _Choix extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choix(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    return Press(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? c.soft : c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? c.ink : c.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: T.strong(c))),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? c.ink : c.muted,
            ),
          ],
        ),
      ),
    );
  }
}
