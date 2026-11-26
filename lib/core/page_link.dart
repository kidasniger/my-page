import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'crypto_box.dart';
import 'facebook.dart';

/// État affiché, déduit des champs « demande » (appli) et « status » (bot).
enum PageEtat { attente, active, erreur, deconnexion, deconnectee }

/// Document users/{uid}/pages/{pageId}.
class LinkedPage {
  final String id;
  final String nom;
  final PageEtat etat;
  final String message;
  const LinkedPage(this.id, this.nom, this.etat, this.message);

  factory LinkedPage.fromMap(String id, Map<String, dynamic> m) {
    final demande = m['demande'];
    final status = m['status'];
    final PageEtat etat;
    if (demande == 'connecter') {
      etat = PageEtat.attente;
    } else if (demande == 'deconnecter') {
      etat = PageEtat.deconnexion;
    } else if (status == 'active') {
      etat = PageEtat.active;
    } else if (status == 'erreur') {
      etat = PageEtat.erreur;
    } else if (status == 'deconnectee') {
      etat = PageEtat.deconnectee;
    } else {
      etat = PageEtat.attente;
    }
    return LinkedPage(
      id,
      '${m['nom'] ?? id}',
      etat,
      etat == PageEtat.erreur ? '${m['message'] ?? ''}' : '',
    );
  }

  /// La Page occupe l'unique place du compte.
  bool get occupe =>
      etat == PageEtat.attente || etat == PageEtat.active;
}

/// Liaison de la Page via Firestore. L'appli écrit seulement nom, tokenEnc,
/// demande et maj ; « status » et « message » appartiennent au bot.
class PageLink {
  static const _delai = Duration(seconds: 15);

  static CollectionReference<Map<String, dynamic>> _col() {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw const FbError("Vous n'êtes pas connecté.");
    return FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('pages');
  }

  /// Suit la Page du compte en direct (null : aucune Page).
  static Stream<LinkedPage?> watch() => _col().limit(5).snapshots().map(
        (s) => current(
          s.docs.map((d) => LinkedPage.fromMap(d.id, d.data())).toList(),
        ),
      );

  /// Choisit la Page à afficher parmi les documents du compte.
  static LinkedPage? current(List<LinkedPage> all) {
    for (final p in all) {
      if (p.occupe) return p;
    }
    for (final p in all) {
      if (p.etat != PageEtat.deconnectee) return p;
    }
    return null;
  }

  /// Chiffre le jeton puis demande la connexion de la Page au bot.
  static Future<void> connect(FbPage page, String token) => _guard(() async {
        final col = _col();
        final snap = await col
            .limit(5)
            .get(const GetOptions(source: Source.server))
            .timeout(_delai);
        for (final d in snap.docs) {
          if (d.id != page.id &&
              LinkedPage.fromMap(d.id, d.data()).occupe) {
            throw const FbError(
              "Déconnectez d'abord la Page déjà liée à ce compte.",
            );
          }
        }
        final tokenEnc = await CryptoBox.encryptWithBundledKey(token);
        await col.doc(page.id).set({
          'nom': String.fromCharCodes(page.name.runes.take(100)),
          'tokenEnc': tokenEnc,
          'demande': 'connecter',
          'maj': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(_delai);
      });

  /// Efface le jeton chiffré et demande la déconnexion au bot.
  static Future<void> disconnect(String pageId) => _guard(() async {
        await _col().doc(pageId).update({
          'tokenEnc': FieldValue.delete(),
          'demande': 'deconnecter',
          'maj': FieldValue.serverTimestamp(),
        }).timeout(_delai);
      });

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
