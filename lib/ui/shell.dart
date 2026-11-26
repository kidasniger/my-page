import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/palette.dart';
import '../core/updater.dart';
import 'common.dart';

/// Bus d'état partagé : badges, thème, recherche de l'accueil, marqueur
/// d'écran externe.
class Bus {
  static final ValueNotifier<int> avis = ValueNotifier(0);
  static final ValueNotifier<int> msg = ValueNotifier(0);
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );

  /// Vrai une fois le jeton et les dépôts chargés du coffre : les écrans
  /// qui lisent le dépôt au démarrage attendent ce signal pour relire
  /// (sinon leurs lectures partent sans jeton et échouent en silence).
  static final ValueNotifier<bool> cfgReady = ValueNotifier(false);
  static final ValueNotifier<bool> chercher = ValueNotifier(false);
  static final ValueNotifier<String> requete = ValueNotifier('');
  static bool external = false;

  static void setAvis(int n) => avis.value = n;
  static void setMsg(int n) => msg.value = n;

  static ThemeMode parse(String s) => s == 'light'
      ? ThemeMode.light
      : s == 'dark'
      ? ThemeMode.dark
      : ThemeMode.system;
}

/* ---------- dialogue de mise à jour avec progression ---------- */

Future<void> kUpdateFlow(BuildContext context, UpdInfo info) async {
  Bus.external = true;
  // 0 proposition, 1 téléchargement, 2 prêt à installer, 3 installation, 4 erreur
  var step = 0;
  var progress = 0.0;
  var failed = '';
  Future<void> Function()? installFn;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final c = ctx.p;
      return StatefulBuilder(
        builder: (ctx2, setD) {
          void safe(VoidCallback f) {
            if (ctx2.mounted) setD(f);
          }

          Future<void> install() async {
            safe(() {
              step = 3;
              failed = '';
            });
            try {
              Bus.external = true;
              await installFn!();
              if (ctx2.mounted) Navigator.pop(ctx2);
            } catch (e) {
              safe(() {
                failed = e.toString();
                step = 4;
              });
            }
          }

          Future<void> download() async {
            safe(() {
              step = 1;
              progress = 0;
              failed = '';
            });
            try {
              final f = await Updater.download(info, (done, total) {
                if (total > 0) safe(() => progress = done / total);
              });
              installFn = () async {
                await Updater.install(f);
              };
              safe(() => step = 2);
            } catch (e) {
              safe(() {
                failed = e.toString();
                step = 4;
              });
            }
          }

          final String texte;
          switch (step) {
            case 1:
              texte = 'Téléchargement...';
              break;
            case 2:
              texte = 'Téléchargement terminé. Appuyez sur Installer pour '
                  'mettre à jour.';
              break;
            case 3:
              texte = 'Installation...';
              break;
            default:
              texte = 'Une nouvelle version de My Page est disponible.';
          }
          return AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: c.line),
            ),
            title: Text(
              info.mandatory
                  ? 'Mise à jour obligatoire'
                  : 'Mise à jour disponible',
              style: T.title(c).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.notes.isNotEmpty) ...[
                  Text(info.notes, style: T.body(c)),
                  const SizedBox(height: 12),
                ],
                if (step != 4) Text(texte, style: T.caption(c)),
                if (step == 1 || step == 3) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: step == 3 ? null : progress,
                      minHeight: 6,
                      backgroundColor: c.soft,
                      valueColor: AlwaysStoppedAnimation(c.accent),
                    ),
                  ),
                ],
                if (step == 4) Text(failed, style: T.body(c)),
              ],
            ),
            actions: [
              if ((step == 0 || step == 2) && !info.mandatory)
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: Text('Plus tard', style: TextStyle(color: c.muted)),
                ),
              if (step == 1)
                TextButton(
                  onPressed: () {
                    Updater.cancelDownload();
                    Navigator.pop(ctx2);
                  },
                  child: Text('Annuler', style: TextStyle(color: c.muted)),
                ),
              if (step == 0)
                TextButton(
                  onPressed: download,
                  child: Text(
                    'Télécharger',
                    style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (step == 2)
                TextButton(
                  onPressed: install,
                  child: Text(
                    'Installer',
                    style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (step == 4)
                TextButton(
                  onPressed: installFn != null ? install : download,
                  child: Text(
                    'Réessayer',
                    style: TextStyle(
                      color: c.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (step == 4)
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: Text('Fermer', style: TextStyle(color: c.muted)),
                ),
            ],
          );
        },
      );
    },
  );
}

/* ---------- écran secondaire plein écran (port du header v1) ---------- */

class SubPage extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SubPage(this.title, {super.key, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 13),
              decoration: BoxDecoration(
                color: c.bg,
                border: Border(bottom: BorderSide(color: c.line)),
              ),
              child: Row(
                children: [
                  Press(
                    onTap: () {
                      Fx.tick();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: c.line),
                      ),
                      child: Icon(Icons.arrow_back_rounded,
                          size: 19, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.title(c).copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('ESPACE DE GESTION',
                            style: T.micro(c).copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
            const BandeauHorsLigne(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
