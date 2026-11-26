import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../ui/common.dart';
import '../ui/shell.dart' show SubPage;

/// Explique chaque permission avant d'ouvrir la connexion.
/// Renvoie true si l'utilisateur choisit de continuer.
class ConnectIntroPage extends StatelessWidget {
  const ConnectIntroPage({super.key});

  static const List<(IconData, String, String)> _items = [
    (
      Icons.list_alt_rounded,
      'Voir la liste de vos Pages',
      'Pour que vous choisissiez la Page à connecter.',
    ),
    (
      Icons.insights_rounded,
      'Lire vos publications et leurs réactions',
      "Pour suivre l'activité de votre Page et préparer les statistiques.",
    ),
    (
      Icons.edit_note_rounded,
      'Publier sur votre Page',
      'Pour publier ou programmer les contenus prévus avec l\'assistant.',
    ),
    (
      Icons.forum_outlined,
      'Gérer les commentaires',
      'Pour répondre aux commentaires et les modérer.',
    ),
    (
      Icons.mail_outline_rounded,
      'Gérer les messages de la Page',
      'Pour répondre aux messages privés envoyés à votre Page.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    return SubPage(
      'Avant de connecter',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Facebook va vous demander les autorisations suivantes. '
            'Voici à quoi sert chacune.',
            style: T.body(c),
          ),
          const SizedBox(height: 16),
          for (final (icon, titre, pourquoi) in _items) ...[
            KCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 22, color: c.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre, style: T.strong(c)),
                        const SizedBox(height: 4),
                        Text(pourquoi, style: T.caption(c)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          Text(
            "Votre jeton d'accès est chiffré sur ce téléphone avant d'être "
            'envoyé. Vous pouvez déconnecter votre Page à tout moment.',
            style: T.caption(c),
          ),
          const SizedBox(height: 20),
          KBtn('Continuer', onTap: () => Navigator.of(context).pop(true)),
          const SizedBox(height: 10),
          KBtnGhost('Annuler', onTap: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }
}
