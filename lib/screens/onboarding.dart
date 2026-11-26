import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../ui/common.dart';

/// Parcours de démarrage de My Page (3 pages) affiché avant la connexion.
/// Aucune barre de navigation : l'écran vit hors de la coquille principale.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide(this.icon, this.title, this.body);
}

const _slides = <_Slide>[
  _Slide(
    Icons.forum_rounded,
    'Votre Page, gérée pour vous',
    'My Page répond aux commentaires et aux messages de votre Page, '
        'selon vos consignes, et vous laisse publier depuis votre téléphone.',
  ),
  _Slide(
    Icons.verified_user_rounded,
    'Ce que My Page demande',
    'Un compte My Page (Google ou e-mail), puis l’accès à votre Page '
        'Facebook : publier, lire et répondre aux commentaires et aux '
        'messages. Rien d’autre.',
  ),
  _Slide(
    Icons.lock_rounded,
    'Vos données restent à vous',
    'Votre accès à la Page est chiffré sur votre téléphone avant l’envoi. '
        'Vous pouvez supprimer votre compte et vos données à tout moment '
        'depuis les réglages.',
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_i >= _slides.length - 1) {
      widget.onDone();
      return;
    }
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.jumpToPage(_i + 1);
    } else {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.p;
    final last = _i == _slides.length - 1;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8, top: 4),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Passer'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (_, k) {
                  final s = _slides[k];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: c.chip,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(s.icon, size: 46, color: c.ink),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: T.hero(c).copyWith(color: c.ink, fontSize: 24),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.body,
                          textAlign: TextAlign.center,
                          style: T.caption(c).copyWith(fontSize: 15, height: 1.45),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < _slides.length; k++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: k == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: k == _i ? c.ink : c.line,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: KBtn(last ? 'Commencer' : 'Suivant', onTap: _next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
