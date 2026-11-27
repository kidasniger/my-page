import 'package:flutter/material.dart';

import '../core/api.dart' show Api;
import '../core/bot_profile.dart';
import '../core/palette.dart';
import '../ui/common.dart';
import '../ui/forms.dart';
import '../ui/shell.dart' show SubPage;

/// Questions du bot au propriétaire : une carte à la fois, Répondre ou Passer.
/// Le bot en crée au plus 3 par jour.
class BotQuestionsPage extends StatelessWidget {
  final String pageId;
  const BotQuestionsPage({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    return SubPage(
      'Questions du bot',
      child: StreamBuilder<BotProfil>(
        stream: BotData.watchProfil(pageId),
        builder: (context, profilSnap) => StreamBuilder<List<BotQuestion>>(
          stream: BotData.watchQuestions(pageId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: ErrBox('lecture des questions impossible.'),
              );
            }
            if (!snap.hasData || !profilSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: KSkeleton(220),
              );
            }
            final questions = snap.data!;
            if (questions.isEmpty) {
              return const KEmpty(
                Icons.check_circle_outline,
                'Aucune question pour le moment',
                sub: 'Le bot vous en posera de nouvelles demain.',
              );
            }
            final q = questions.first;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _CarteQuestion(
                  key: ValueKey(q.id),
                  pageId: pageId,
                  question: q,
                  profil: profilSnap.data!,
                  rang: 1,
                  total: questions.length,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CarteQuestion extends StatefulWidget {
  final String pageId;
  final BotQuestion question;
  final BotProfil profil;
  final int rang, total;
  const _CarteQuestion({
    super.key,
    required this.pageId,
    required this.question,
    required this.profil,
    required this.rang,
    required this.total,
  });
  @override
  State<_CarteQuestion> createState() => _CarteQuestionState();
}

class _CarteQuestionState extends State<_CarteQuestion> {
  final _texte = TextEditingController();
  String _choix = '';
  bool _busy = false;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  List<(String, String)> get _options {
    final q = widget.question;
    if (q.type == 'ouinon') return const [('Oui', 'Oui'), ('Non', 'Non')];
    return [
      for (final o in q.options)
        (o, BotProfil.tonLabels[o] ?? BotProfil.langues[o] ?? o),
    ];
  }

  Future<void> _agir(bool repondre) async {
    final q = widget.question;
    final reponse = q.type == 'texte' ? _texte.text.trim() : _choix;
    if (repondre && reponse.isEmpty) {
      kToast(context, 'Donnez une réponse, ou passez.');
      return;
    }
    setState(() => _busy = true);
    try {
      if (repondre) {
        await BotData.repondre(widget.pageId, q, reponse, widget.profil);
      } else {
        await BotData.passer(q);
      }
      if (mounted) kToast(context, repondre ? 'Réponse enregistrée.' : 'Question passée.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      kToast(context, Api.hint(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final q = widget.question;
    return KCard(
      pad: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'QUESTION ${widget.rang} SUR ${widget.total}',
                  style: T.micro(c),
                ),
              ),
              StatusChip(q.origine == 'ia' ? 'Vos clients' : 'Profil'),
            ],
          ),
          const SizedBox(height: 12),
          Text(q.texte, style: T.title(c).copyWith(fontSize: 18)),
          const SizedBox(height: 16),
          if (q.type == 'texte')
            KEdit(
              controller: _texte,
              hint: 'Votre réponse',
              minLines: 2,
              maxLines: 5,
              maxLength: 400,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (val, label) in _options)
                  Press(
                    onTap: () => setState(() => _choix = val),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: _choix == val ? c.ink : c.card,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _choix == val ? c.ink : c.line),
                      ),
                      child: Text(
                        label,
                        style: T.strong(c).copyWith(
                              color: _choix == val ? c.bg : c.ink,
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 20),
          KBtn('Répondre', busy: _busy, onTap: () => _agir(true)),
          const SizedBox(height: 10),
          KBtnGhost('Passer', onTap: _busy ? null : () => _agir(false)),
        ],
      ),
    );
  }
}
