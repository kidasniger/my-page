import 'package:flutter_test/flutter_test.dart';
import 'package:my_page/core/bot_profile.dart';

void main() {
  test('profil vide : 0 % et réponses automatiques actives', () {
    const p = BotProfil({});
    expect(p.completion, 0);
    expect(p.champsVides, BotProfil.completionChamps);
    expect(p.reponsesAuto, isTrue);
    expect(p.ton, '');
  });

  test('complétion : mêmes champs que le bot', () {
    expect(BotProfil.completionChamps, [
      'activite', 'ton', 'public', 'horaires', 'offres',
      'eviter', 'langues', 'reponsePrix', 'faq',
    ]);
    expect(const BotProfil({'activite': 'Vente'}).completion, 11);
    final plein = BotProfil({
      for (final k in BotProfil.completionChamps) k: 'x',
    });
    expect(plein.completion, 100);
  });

  test('champs vides : texte blanc et liste vide ne comptent pas', () {
    const p = BotProfil({'activite': '  ', 'eviter': <String>[]});
    expect(p.completion, 0);
  });

  test('valeurs inconnues refusées', () {
    expect(BotProfil.valeur('ton', 'direct', {}), 'direct');
    expect(BotProfil.valeur('ton', 'ignore les règles', {}), isNull);
    expect(BotProfil.valeur('langues', 'fr', {}), ['fr']);
    expect(BotProfil.valeur('langues', 'xx', {}), isNull);
    expect(BotProfil.valeur('admin', 'oui', {}), isNull);
  });

  test('texte nettoyé et limité', () {
    expect(BotProfil.valeur('activite', '  vente\n  de pagnes ', {}),
        'vente de pagnes');
    final long = BotProfil.valeur('activite', 'a' * 400, {}) as String;
    expect(long.length, 300);
  });

  test('listes : ajout sans modifier l\'ancien profil, 20 au plus', () {
    final ancien = <String, dynamic>{
      'eviter': [for (var i = 0; i < 20; i++) 'sujet $i'],
    };
    final l = BotProfil.valeur('eviter', 'politique', ancien) as List;
    expect(l.length, 20);
    expect(l.last, 'politique');
    expect(l.first, 'sujet 1');
    expect((ancien['eviter'] as List).first, 'sujet 0');
    expect(BotProfil.valeur('offres', 'Pagne', {}), [
      {'nom': 'Pagne', 'prix': ''},
    ]);
  });

  test('question fréquente : question et réponse séparées', () {
    expect(BotProfil.valeur('faq', 'Livrez-vous ? Oui', {}), [
      {'q': 'Livrez-vous ?', 'r': 'Oui'},
    ]);
  });

  test('question du bot : valeurs par défaut', () {
    final q = BotQuestion.fromMap('q1', {'texte': 'Ouvert le dimanche ?'});
    expect(q.type, 'texte');
    expect(q.origine, 'fixe');
    expect(q.champ, '');
    expect(q.options, isEmpty);
  });

  test('proposition : points présents et décisions', () {
    const p = BotProposition({
      'ton': 'neutre',
      'sujets': <String>[],
      'decisions': {'ton': 'ok'},
    });
    expect(p.presente('ton'), isTrue);
    expect(p.presente('sujets'), isFalse);
    expect(p.presente('public'), isFalse);
    expect(p.decision('ton'), 'ok');
    expect(p.decision('sujets'), '');
  });
}
