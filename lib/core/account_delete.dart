import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Suppression des données de l'utilisateur dans Firestore.
/// Le dossier quota n'est pas supprimable par le client (règles de
/// sécurité) : il est nettoyé par le bot.
class AccountData {
  static const _subs = [
    'pages',
    'inbox',
    'stats',
    'profil',
    'proposition',
    'questions',
    'file',
  ];

  /// Renvoie null en cas de réussite, sinon un message en français.
  static Future<String?> deleteAll() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return "Vous n'êtes pas connecté.";
    final db = FirebaseFirestore.instance;
    final root = db.collection('users').doc(u.uid);
    try {
      for (final name in _subs) {
        while (true) {
          final snap = await root.collection(name).limit(400).get();
          if (snap.docs.isEmpty) break;
          final batch = db.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
          if (snap.docs.length < 400) break;
        }
      }
      await root.delete();
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Suppression refusée par les règles de sécurité.';
      }
      if (e.code == 'unavailable') return 'Pas de connexion internet.';
      return 'Suppression impossible (${e.code}).';
    } catch (_) {
      return 'Une erreur est survenue. Réessayez.';
    }
  }
}
