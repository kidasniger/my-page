import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'facebook.dart';

String _court(String s, int n) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return String.fromCharCodes(t.runes.take(n));
}

/// Profil du bot d'une Page : users/{uid}/profil/{pageId}.
/// Même schéma que scripts/profil_page.py (facebook-manager).
class BotProfil {
  static const tons = ['chaleureux', 'neutre', 'direct'];
  static const tonLabels = {
    'chaleureux': 'Chaleureux',
    'neutre': 'Neutre',
    'direct': 'Direct',
  };
  static const langues = {
    'fr': 'Français',
    'en': 'Anglais',
    'ha': 'Haoussa',
    'dje': 'Zarma',
  };
  static const completionChamps = [
    'activite', 'ton', 'public', 'horaires', 'offres',
    'eviter', 'langues', 'reponsePrix', 'faq',
  ];
  static const _textes = {
    'activite': 300, 'public': 200, 'horaires': 200, 'reponsePrix': 300,
  };

  final Map<String, dynamic> data;
  const BotProfil(this.data);

  String texte(String k) => '${data[k] ?? ''}'.trim();

  List<String> liste(String k) {
    final v = data[k];
    if (v is! List) return const [];
    return [for (final e in v) if ('$e'.trim().isNotEmpty) '$e'.trim()];
  }

  List<Map<String, String>> paires(String k, String a, String b) {
    final v = data[k];
    if (v is! List) return const [];
    return [
      for (final e in v)
        if (e is Map) {a: '${e[a] ?? ''}', b: '${e[b] ?? ''}'},
    ];
  }

  String get ton => tons.contains(data['ton']) ? data['ton'] as String : '';
  bool get reponsesAuto => data['reponsesAuto'] != false;

  Map<String, dynamic> get silence => data['silence'] is Map
      ? Map<String, dynamic>.from(data['silence'] as Map)
      : const {};

  bool rempli(String k) {
    final v = data[k];
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  List<String> get champsVides =>
      [for (final k in completionChamps) if (!rempli(k)) k];

  int get completion =>
      ((completionChamps.length - champsVides.length) *
              100 /
              completionChamps.length)
          .round();

  static List<dynamic> _ancien(Map<String, dynamic> m, String k) =>
      m[k] is List ? List<dynamic>.from(m[k] as List) : <dynamic>[];

  /// Ajoute une question fréquente (au plus 20).
  static List<dynamic> ajouterFaq(
      Map<String, dynamic> actuel, String q, String r) {
    final l = _ancien(actuel, 'faq')
      ..add({'q': _court(q, 200), 'r': _court(r, 400)});
    return l.length > 20 ? l.sublist(l.length - 20) : l;
  }

  /// Valeur à enregistrer dans `champ` pour une réponse (questionnaire ou question du bot).
  static dynamic valeur(String champ, String reponse, Map<String, dynamic> actuel) {
    final r = reponse.trim();
    switch (champ) {
      case 'ton':
        return tons.contains(r) ? r : null;
      case 'langues':
        return langues.containsKey(r) ? [r] : null;
      case 'eviter':
        final l = _ancien(actuel, 'eviter')..add(_court(r, 100));
        return l.length > 20 ? l.sublist(l.length - 20) : l;
      case 'offres':
        final l = _ancien(actuel, 'offres')..add({'nom': _court(r, 80), 'prix': ''});
        return l.length > 20 ? l.sublist(l.length - 20) : l;
      case 'faq':
        final i = r.indexOf('?');
        return i > 0 && i < r.length - 1
            ? ajouterFaq(actuel, r.substring(0, i + 1), r.substring(i + 1))
            : ajouterFaq(actuel, 'Question fréquente', r);
      default:
        final n = _textes[champ];
        return n == null ? null : _court(r, n);
    }
  }
}

/// Question au propriétaire : users/{uid}/questions/{id} (créée par le bot).
class BotQuestion {
  final String id, texte, type, origine, champ;
  final List<String> options;
  const BotQuestion(this.id, this.texte, this.type, this.origine, this.champ, this.options);

  factory BotQuestion.fromMap(String id, Map<String, dynamic> m) => BotQuestion(
        id,
        '${m['texte'] ?? ''}',
        '${m['type'] ?? 'texte'}',
        '${m['origine'] ?? 'fixe'}',
        '${m['champ'] ?? ''}',
        m['options'] is List ? [for (final o in m['options'] as List) '$o'] : const [],
      );
}

/// Proposition du bot (lecture des posts) : users/{uid}/proposition/{pageId}.
/// Jamais appliquée seule : chaque point est validé ou corrigé par le propriétaire.
class BotProposition {
  static const points = ['ton', 'sujets', 'langues', 'activite', 'public'];
  final Map<String, dynamic> data;
  const BotProposition(this.data);

  String get etat => '${data['etat'] ?? ''}';

  String decision(String point) {
    final d = data['decisions'];
    return d is Map ? '${d[point] ?? ''}' : '';
  }

  bool presente(String point) {
    final v = data[point];
    if (v is List) return v.isNotEmpty;
    return '${v ?? ''}'.trim().isNotEmpty;
  }

  dynamic valeur(String point) => data[point];
}

/// Accès Firestore aux données de personnalisation (règles de sécurité côté serveur).
class BotData {
  static const _delai = Duration(seconds: 15);

  static DocumentReference<Map<String, dynamic>> _user() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw const FbError("Vous n'êtes pas connecté.");
    return FirebaseFirestore.instance.collection('users').doc(u.uid);
  }

  static DocumentReference<Map<String, dynamic>> _profil(String pageId) =>
      _user().collection('profil').doc(pageId);
  static DocumentReference<Map<String, dynamic>> _proposition(String pageId) =>
      _user().collection('proposition').doc(pageId);
  static CollectionReference<Map<String, dynamic>> _questions() =>
      _user().collection('questions');

  static Map<String, dynamic> _avecCompletion(
      BotProfil actuel, Map<String, dynamic> changes) {
    final fusion = {...actuel.data, ...changes};
    return {
      ...changes,
      'completion': BotProfil(fusion).completion,
      'maj': FieldValue.serverTimestamp(),
    };
  }

  static Stream<BotProfil> watchProfil(String pageId) =>
      _profil(pageId).snapshots().map((s) => BotProfil(s.data() ?? const {}));

  static Future<void> saveProfil(
          String pageId, BotProfil actuel, Map<String, dynamic> changes) =>
      _guard(() => _profil(pageId)
          .set(_avecCompletion(actuel, changes), SetOptions(merge: true))
          .timeout(_delai));

  static Stream<List<BotQuestion>> watchQuestions(String pageId) => _questions()
      .where('pageId', isEqualTo: pageId)
      .where('etat', isEqualTo: 'ouverte')
      .limit(10)
      .snapshots()
      .map((s) => [for (final d in s.docs) BotQuestion.fromMap(d.id, d.data())]);

  /// Répond à une question et met le profil à jour dans le même lot.
  static Future<void> repondre(
          String pageId, BotQuestion q, String reponse, BotProfil profil) =>
      _guard(() async {
        final dynamic v = q.champ.isNotEmpty
            ? BotProfil.valeur(q.champ, reponse, profil.data)
            : BotProfil.ajouterFaq(profil.data, q.texte, reponse);
        final batch = FirebaseFirestore.instance.batch();
        batch.update(_questions().doc(q.id), {
          'etat': 'repondue',
          'reponse': _court(reponse, 400),
          'reponduLe': FieldValue.serverTimestamp(),
        });
        if (v != null) {
          final champ = q.champ.isNotEmpty ? q.champ : 'faq';
          batch.set(_profil(pageId), _avecCompletion(profil, {champ: v}),
              SetOptions(merge: true));
        }
        await batch.commit().timeout(_delai);
      });

  static Future<void> passer(BotQuestion q) => _guard(() => _questions()
      .doc(q.id)
      .update({'etat': 'passee', 'reponduLe': FieldValue.serverTimestamp()})
      .timeout(_delai));

  static Stream<BotProposition?> watchProposition(String pageId) =>
      _proposition(pageId)
          .snapshots()
          .map((s) => s.exists ? BotProposition(s.data() ?? const {}) : null);

  /// Valide (valeur proposée) ou corrige (valeur saisie) un point de la proposition.
  static Future<void> decider(String pageId, String point, dynamic valeur,
          bool corrige, BotProfil profil) =>
      _guard(() async {
        final batch = FirebaseFirestore.instance.batch();
        batch.set(
            _proposition(pageId),
            {'decisions': {point: corrige ? 'corrige' : 'ok'}},
            SetOptions(merge: true));
        batch.set(_profil(pageId), _avecCompletion(profil, {point: valeur}),
            SetOptions(merge: true));
        await batch.commit().timeout(_delai);
      });

  /// Demande au bot une nouvelle analyse des posts (au prochain passage quotidien).
  static Future<void> redemander(String pageId) => _guard(() => _proposition(pageId)
      .set({'etat': 'redemande'}, SetOptions(merge: true))
      .timeout(_delai));

  static Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } on FbError {
      rethrow;
    } on TimeoutException {
      throw const FbError('Connexion trop lente. Vérifiez internet.');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const FbError('Écriture refusée par les règles de sécurité.');
      }
      if (e.code == 'unavailable') {
        throw const FbError('Pas de connexion internet.');
      }
      throw FbError('Enregistrement impossible (${e.code}).');
    } catch (_) {
      throw const FbError('Une erreur est survenue. Réessayez.');
    }
  }
}
