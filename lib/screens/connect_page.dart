import 'package:flutter/material.dart';

import '../core/facebook.dart';
import '../core/page_link.dart';
import '../core/palette.dart';
import '../ui/common.dart';
import '../ui/forms.dart' show ErrBox, kConfirm;
import '../ui/shell.dart' show SubPage;
import '../widgets/page_avatar.dart';
import 'connect_intro.dart';

/// Écran « Ma Page » : connexion, état écrit par le bot, déconnexion.
class ConnectPageScreen extends StatefulWidget {
  const ConnectPageScreen({super.key});
  @override
  State<ConnectPageScreen> createState() => _ConnectPageScreenState();
}

class _ConnectPageScreenState extends State<ConnectPageScreen> {
  static const _droits = {
    'pages_show_list': 'voir la liste des Pages',
    'pages_read_engagement': 'lire les publications',
    'pages_manage_posts': 'publier',
    'pages_manage_engagement': 'gérer les commentaires',
    'pages_messaging': 'gérer les messages',
  };

  late Stream<LinkedPage?> _stream = PageLink.watch();
  bool _busy = false;
  String? _err;

  void _reload() => setState(() => _stream = PageLink.watch());

  Future<void> _connect() async {
    if (_busy) return;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ConnectIntroPage()),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    String? err;
    try {
      // Le jeton reste dans cette variable locale, jamais affiché.
      final token = await Facebook.login();
      if (token != null) {
        final manque = await Facebook.missingPermissions(token);
        if (manque.isNotEmpty) {
          final noms = manque.map((p) => _droits[p] ?? p).join(', ');
          throw FbError('Autorisations manquantes : $noms.');
        }
        final pages = await Facebook.pages(token);
        if (pages.isEmpty) {
          throw const FbError('Aucune Page trouvée pour ce compte.');
        }
        if (!mounted) return;
        final page = await _choose(pages);
        if (page != null) {
          await PageLink.connect(page, token);
          if (mounted) kToast(context, 'Demande envoyée.');
        }
      }
    } on FbError catch (e) {
      err = e.message;
    } catch (_) {
      err = 'Une erreur est survenue. Réessayez.';
    } finally {
      await Facebook.logout();
      if (mounted) {
        setState(() {
          _busy = false;
          _err = err;
        });
      }
    }
  }

  Future<FbPage?> _choose(List<FbPage> pages) {
    final c = context.p;
    return showDialog<FbPage>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: c.card,
        title: Text('Choisissez une Page', style: T.title(c)),
        children: [
          for (final p in pages)
            SimpleDialogOption(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              onPressed: () => Navigator.pop(ctx, p),
              child: Row(
                children: [
                  PageAvatar(p.id, p.name, size: 36),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.name, style: T.strong(c))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _disconnect(LinkedPage page) async {
    if (_busy) return;
    final ok = await kConfirm(context, 'Déconnecter la Page ${page.nom} ?');
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    String? err;
    try {
      await PageLink.disconnect(page.id);
    } on FbError catch (e) {
      err = e.message;
    }
    if (mounted) {
      setState(() {
        _busy = false;
        _err = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      'Ma Page',
      child: StreamBuilder<LinkedPage?>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const ErrBox('Impossible de lire l\'état de la Page.'),
                const SizedBox(height: 16),
                KBtn('Réessayer', onTap: _reload),
              ],
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ..._content(context, snap.data),
              if (_err != null) ...[
                const SizedBox(height: 14),
                ErrBox(_err!),
              ],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(BuildContext context, LinkedPage? page) {
    if (page == null || page.etat == PageEtat.deconnectee) {
      return [
        const KEmpty(
          Icons.link_rounded,
          'Aucune Page connectée',
          sub: 'Connectez une Page pour activer votre assistant.',
        ),
        KBtn(
          'Connecter ma Page',
          busy: _busy,
          onTap: _connect,
          leading: Image.asset(
            'assets/images/facebook.png',
            width: 22,
            height: 22,
            cacheWidth: 66,
            excludeFromSemantics: true,
          ),
        ),
      ];
    }
    final c = context.p;
    final (label, texte) = switch (page.etat) {
      PageEtat.attente => (
          'En attente',
          "L'assistant va traiter votre demande. "
              'Cela peut prendre quelques minutes.',
        ),
      PageEtat.active => ('Active', 'Votre Page est connectée.'),
      PageEtat.erreur => ('Erreur', 'La connexion a échoué.'),
      PageEtat.deconnexion => (
          'Déconnexion en cours',
          "L'assistant va retirer votre Page.",
        ),
      PageEtat.deconnectee => ('Déconnectée', ''),
    };
    final encours = page.etat == PageEtat.deconnexion;
    return [
      KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PageAvatar(page.id, page.nom, size: 48),
                const SizedBox(width: 12),
                Expanded(child: Text(page.nom, style: T.title(c))),
              ],
            ),
            const SizedBox(height: 10),
            StatusChip(label, kind: page.etat == PageEtat.active ? 3 : 2),
            const SizedBox(height: 10),
            Text(texte, style: T.body(c)),
          ],
        ),
      ),
      if (page.message.isNotEmpty) ...[
        const SizedBox(height: 12),
        ErrBox(page.message),
      ],
      const SizedBox(height: 18),
      if (page.etat == PageEtat.erreur || encours) ...[
        KBtn(
          encours ? 'Connecter ma Page' : 'Réessayer',
          busy: _busy,
          onTap: _connect,
        ),
        const SizedBox(height: 10),
      ],
      if (!encours)
        KBtnGhost(
          'Déconnecter ma Page',
          onTap: _busy ? null : () => _disconnect(page),
        ),
    ];
  }
}
