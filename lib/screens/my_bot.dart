import 'package:flutter/material.dart';

import '../core/api.dart' show Api;
import '../core/bot_profile.dart';
import '../core/page_link.dart';
import '../core/palette.dart';
import '../ui/common.dart';
import '../ui/forms.dart';
import 'bot_questionnaire.dart';
import 'bot_questions.dart';
import 'bot_understood.dart';

String _hh(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _tod(String s, TimeOfDay defaut) {
  final p = s.split(':');
  if (p.length != 2) return defaut;
  final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
  if (h == null || m == null) return defaut;
  return TimeOfDay(hour: h, minute: m);
}

/// Mon bot (sans barre de titre : onglet ou SubPage) : profil lisible, complétion, réglages simples, questions et analyse.
class MyBotPage extends StatelessWidget {
  const MyBotPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LinkedPage?>(
        stream: PageLink.watch(),
        builder: (context, pageSnap) {
          if (pageSnap.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: KSkeleton(260));
          }
          final page = pageSnap.data;
          if (page == null || page.etat != PageEtat.active) {
            return const KEmpty(
              Icons.link_off_rounded,
              'Aucune Page active',
              sub: 'Connectez votre Page pour configurer votre bot.',
            );
          }
          return StreamBuilder<BotProfil>(
            stream: BotData.watchProfil(page.id),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: ErrBox('lecture du profil impossible.'),
                );
              }
              if (!snap.hasData) {
                return const Padding(padding: EdgeInsets.all(20), child: KSkeleton(260));
              }
              return _Contenu(pageId: page.id, profil: snap.data!);
            },
          );
        },
    );
  }
}

class _Contenu extends StatelessWidget {
  final String pageId;
  final BotProfil profil;
  const _Contenu({required this.pageId, required this.profil});

  void _ouvrir(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  Future<void> _enregistrer(BuildContext context, Map<String, dynamic> changes,
      String ok) async {
    try {
      await BotData.saveProfil(pageId, profil, changes);
      if (context.mounted) kToast(context, ok);
    } catch (e) {
      if (context.mounted) kToast(context, Api.hint(e), bad: true);
    }
  }

  Map<String, dynamic> _silence({bool? actif, String? debut, String? fin}) {
    final s = profil.silence;
    return {
      'silence': {
        'actif': actif ?? (s['actif'] == true),
        'debut': debut ?? '${s['debut'] ?? '22:00'}',
        'fin': fin ?? '${s['fin'] ?? '07:00'}',
        'decalageMin': DateTime.now().timeZoneOffset.inMinutes,
      },
    };
  }

  Future<void> _heure(BuildContext context, bool debut) async {
    final s = profil.silence;
    final actuel = debut
        ? _tod('${s['debut'] ?? ''}', const TimeOfDay(hour: 22, minute: 0))
        : _tod('${s['fin'] ?? ''}', const TimeOfDay(hour: 7, minute: 0));
    final t = await showTimePicker(context: context, initialTime: actuel);
    if (t == null || !context.mounted) return;
    await _enregistrer(
      context,
      debut ? _silence(debut: _hh(t)) : _silence(fin: _hh(t)),
      'Heures de silence enregistrées.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final pct = profil.completion;
    final s = profil.silence;
    final offres = [
      for (final o in profil.paires('offres', 'nom', 'prix'))
        o['prix']!.isEmpty ? o['nom']! : '${o['nom']} (${o['prix']})',
    ].join(', ');
    final tonIndex = BotProfil.tons.indexOf(profil.ton);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        KHero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROFIL DU BOT', style: T.micro(c).copyWith(color: c.heroMut)),
              const SizedBox(height: 6),
              Text('$pct %', style: T.hero(c)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5,
                  backgroundColor: c.heroMut.withValues(alpha: .3),
                  valueColor: AlwaysStoppedAnimation(c.heroInk),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                pct >= 100
                    ? 'Votre bot connaît bien votre Page.'
                    : 'Plus le profil est complet, plus les réponses sont justes.',
                style: T.caption(c).copyWith(color: c.heroMut),
              ),
              const SizedBox(height: 14),
              KBtn(
                pct >= 100 ? 'Modifier le profil' : 'Compléter le profil',
                onTap: () => _ouvrir(
                  context,
                  BotQuestionnairePage(pageId: pageId, profil: profil),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        RouteRow(
          Icons.help_outline_rounded,
          'Questions du bot',
          sub: 'Répondez pour qu\'il réponde mieux.',
          onTap: () => _ouvrir(context, BotQuestionsPage(pageId: pageId)),
        ),
        RouteRow(
          Icons.auto_awesome_outlined,
          "Ce que j'ai compris",
          sub: 'Résumé de votre Page, à valider.',
          onTap: () => _ouvrir(context, BotUnderstoodPage(pageId: pageId)),
        ),
        const SizedBox(height: 22),
        const KSection('Réglages'),
        KCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KSwitchRow(
                'Réponses automatiques',
                key: ValueKey('auto${profil.reponsesAuto}'),
                desc: 'Le bot répond seul aux commentaires.',
                value: profil.reponsesAuto,
                job: (v) => BotData.saveProfil(pageId, profil, {'reponsesAuto': v}),
              ),
              const KDivider(),
              Text('Ton des réponses', style: T.strong(c).copyWith(fontSize: 15)),
              const SizedBox(height: 8),
              KSegmented(
                [for (final t in BotProfil.tons) BotProfil.tonLabels[t]!],
                sel: tonIndex < 0 ? -1 : tonIndex,
                fontSize: 13,
                onSelect: (i) => _enregistrer(
                  context,
                  {'ton': BotProfil.tons[i]},
                  'Ton enregistré.',
                ),
              ),
              const KDivider(),
              KSwitchRow(
                'Heures de silence',
                key: ValueKey('silence${s['actif'] == true}'),
                desc: 'Aucune réponse pendant cette plage.',
                value: s['actif'] == true,
                job: (v) => BotData.saveProfil(pageId, profil, _silence(actif: v)),
              ),
              if (s['actif'] == true) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: KBtnGhost(
                        'De ${s['debut'] ?? '22:00'}',
                        onTap: () => _heure(context, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KBtnGhost(
                        'À ${s['fin'] ?? '07:00'}',
                        onTap: () => _heure(context, false),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _MotsInterdits(pageId: pageId, profil: profil),
        const SizedBox(height: 22),
        const KSection('Ce que sait le bot'),
        KCard(
          child: Column(
            children: [
              _Ligne('Activité', profil.texte('activite')),
              _Ligne('Ton', BotProfil.tonLabels[profil.ton] ?? ''),
              _Ligne('Public', profil.texte('public')),
              _Ligne('Horaires', profil.texte('horaires')),
              _Ligne('Offres', offres),
              _Ligne('À éviter', profil.liste('eviter').join(', ')),
              _Ligne('Langue', [
                for (final l in profil.liste('langues')) BotProfil.langues[l] ?? l,
              ].join(', ')),
              _Ligne('Réponse aux prix', profil.texte('reponsePrix')),
              _Ligne(
                'Questions fréquentes',
                profil.paires('faq', 'q', 'r').isEmpty
                    ? ''
                    : '${profil.paires('faq', 'q', 'r').length}',
                dernier: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Ligne extends StatelessWidget {
  final String label, valeur;
  final bool dernier;
  const _Ligne(this.label, this.valeur, {this.dernier = false});
  @override
  Widget build(BuildContext context) {
    final c = context.p;
    return Padding(
      padding: EdgeInsets.only(bottom: dernier ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: T.caption(c))),
          Expanded(
            child: Text(
              valeur.isEmpty ? 'Non renseigné' : valeur,
              style: valeur.isEmpty ? T.caption(c) : T.body(c),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotsInterdits extends StatefulWidget {
  final String pageId;
  final BotProfil profil;
  const _MotsInterdits({required this.pageId, required this.profil});
  @override
  State<_MotsInterdits> createState() => _MotsInterditsState();
}

class _MotsInterditsState extends State<_MotsInterdits> {
  final _texte = TextEditingController();

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _sauver(List<String> mots) => BotData.saveProfil(
      widget.pageId, widget.profil, {'motsInterdits': mots.take(50).toList()});

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final mots = widget.profil.liste('motsInterdits');
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mots interdits', style: T.strong(c).copyWith(fontSize: 15)),
          Text(
            'Un commentaire qui en contient est mis de côté pour vous.',
            style: T.caption(c),
          ),
          const SizedBox(height: 10),
          if (mots.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in mots)
                  Press(
                    onTap: () async {
                      if (!await kConfirm(context, 'Retirer « $m » ?')) return;
                      try {
                        await _sauver([for (final x in mots) if (x != m) x]);
                      } catch (e) {
                        if (context.mounted) kToast(context, Api.hint(e), bad: true);
                      }
                    },
                    child: StatusChip(m, kind: 1),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: KEdit(controller: _texte, hint: 'Ajouter un mot', maxLength: 40)),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: ActionBtn(
                  'Ajouter',
                  variant: KBtnVariant.ghost,
                  job: () async {
                    final m = _texte.text.trim();
                    if (m.length < 2 || mots.contains(m)) return;
                    await _sauver([...mots, m]);
                    _texte.clear();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
