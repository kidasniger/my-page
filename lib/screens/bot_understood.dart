import 'package:flutter/material.dart';

import '../core/bot_profile.dart';
import '../core/palette.dart';
import '../ui/common.dart';
import '../ui/forms.dart';
import '../ui/shell.dart' show SubPage;

const _titres = {
  'ton': 'Ton',
  'sujets': 'Sujets de la Page',
  'langues': 'Langue',
  'activite': 'Activité',
  'public': 'Public',
};

String _affiche(String point, dynamic v) {
  if (v is List) {
    return [
      for (final e in v)
        point == 'langues' ? (BotProfil.langues['$e'] ?? '$e') : '$e',
    ].join(', ');
  }
  if (point == 'ton') return BotProfil.tonLabels['$v'] ?? '$v';
  return '${v ?? ''}';
}

/// Ce que le bot a compris de la Page (lecture des posts).
/// Chaque point est validé ou corrigé par le propriétaire ; rien n'est appliqué seul.
class BotUnderstoodPage extends StatelessWidget {
  final String pageId;
  const BotUnderstoodPage({super.key, required this.pageId});

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    return SubPage(
      "Ce que j'ai compris",
      child: StreamBuilder<BotProfil>(
        stream: BotData.watchProfil(pageId),
        builder: (context, profilSnap) => StreamBuilder<BotProposition?>(
          stream: BotData.watchProposition(pageId),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: ErrBox('lecture impossible.'),
              );
            }
            if (snap.connectionState == ConnectionState.waiting ||
                !profilSnap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: KSkeleton(220),
              );
            }
            final prop = snap.data;
            if (prop == null || prop.etat == 'redemande') {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  KEmpty(
                    Icons.auto_awesome_outlined,
                    prop == null ? 'Pas encore d\'analyse' : 'Analyse demandée',
                    sub: 'Le bot lira vos derniers posts lors de son passage '
                        'quotidien, puis vous montrera ce qu\'il a compris.',
                  ),
                  if (prop == null)
                    ActionBtn(
                      "Demander l'analyse",
                      job: () => BotData.redemander(pageId),
                      ok: 'Analyse demandée.',
                    ),
                ],
              );
            }
            final points = [
              for (final p in BotProposition.points)
                if (prop.presente(p)) p,
            ];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Voici ce que le bot a déduit de vos posts. Validez ce qui '
                  'est juste et corrigez le reste : il ne l\'utilisera '
                  'qu\'après votre accord.',
                  style: T.body(c),
                ),
                const SizedBox(height: 16),
                for (final p in points) ...[
                  _Point(
                    pageId: pageId,
                    point: p,
                    proposition: prop,
                    profil: profilSnap.data!,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 10),
                ActionBtn(
                  "Refaire l'analyse",
                  variant: KBtnVariant.ghost,
                  job: () => BotData.redemander(pageId),
                  ok: 'Nouvelle analyse demandée.',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final String pageId, point;
  final BotProposition proposition;
  final BotProfil profil;
  const _Point({
    required this.pageId,
    required this.point,
    required this.proposition,
    required this.profil,
  });

  Future<void> _corriger(BuildContext context) async {
    final v = await kSheet<dynamic>(
      context,
      title: 'Corriger : ${_titres[point]}',
      children: [_Correction(point: point, actuel: proposition.valeur(point))],
    );
    if (v == null) return;
    await BotData.decider(pageId, point, v, true, profil);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final d = proposition.decision(point);
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_titres[point]!.toUpperCase(), style: T.micro(c))),
              StatusChip(
                d == 'ok' ? 'Validé' : d == 'corrige' ? 'Corrigé' : 'À vérifier',
                kind: d.isEmpty ? 0 : 1,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_affiche(point, proposition.valeur(point)), style: T.strong(c)),
          if (d.isEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ActionBtn(
                    "C'est juste",
                    job: () => BotData.decider(
                        pageId, point, proposition.valeur(point), false, profil),
                    ok: 'Validé.',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ActionBtn(
                    'Corriger',
                    variant: KBtnVariant.ghost,
                    job: () => _corriger(context),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Saisie d'une correction ; renvoie la valeur au format du profil.
class _Correction extends StatefulWidget {
  final String point;
  final dynamic actuel;
  const _Correction({required this.point, required this.actuel});
  @override
  State<_Correction> createState() => _CorrectionState();
}

class _CorrectionState extends State<_Correction> {
  late final _texte = TextEditingController(
    text: widget.actuel is List
        ? (widget.actuel as List).join(', ')
        : '${widget.actuel ?? ''}',
  );
  String _choix = '';

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Map<String, String>? get _options => widget.point == 'ton'
      ? BotProfil.tonLabels
      : widget.point == 'langues'
          ? BotProfil.langues
          : null;

  dynamic _valeur() {
    final t = _texte.text.trim();
    switch (widget.point) {
      case 'ton':
        return _choix.isEmpty ? null : _choix;
      case 'langues':
        return _choix.isEmpty ? null : [_choix];
      case 'sujets':
        final l = [
          for (final s in t.split(','))
            if (s.trim().isNotEmpty) s.trim(),
        ];
        return l.isEmpty ? null : l.take(8).toList();
      default:
        return t.isEmpty ? null : t;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final options = _options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (options == null) ...[
          KEdit(
            controller: _texte,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            hint: widget.point == 'sujets'
                ? 'Sujets séparés par des virgules'
                : 'Votre correction',
          ),
        ] else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in options.entries)
                Press(
                  onTap: () => setState(() => _choix = e.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: _choix == e.key ? c.ink : c.card,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _choix == e.key ? c.ink : c.line),
                    ),
                    child: Text(
                      e.value,
                      style: T.strong(c).copyWith(
                            color: _choix == e.key ? c.bg : c.ink,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        KBtn(
          'Enregistrer',
          onTap: () {
            final v = _valeur();
            if (v == null) {
              kToast(context, 'Saisissez une valeur.');
              return;
            }
            Navigator.of(context).pop(v);
          },
        ),
      ],
    );
  }
}
