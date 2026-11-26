import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// Connexion à My Page : Google ou e-mail, via Firebase Authentication.
/// Chaque méthode renvoie null en cas de réussite, une chaîne vide si
/// l'utilisateur a annulé, sinon un message d'erreur en français.
class Auth {
  static bool _googleReady = false;

  static User? get user => FirebaseAuth.instance.currentUser;
  static Stream<User?> get changes => FirebaseAuth.instance.authStateChanges();

  static Future<String?> signInGoogle() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          serverClientId: DefaultFirebaseOptions.webClientId,
        );
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return 'Connexion Google impossible : jeton manquant.';
      }
      final cred = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(cred);
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) return '';
      return 'Connexion Google impossible. Réessayez.';
    }
  }

  static Future<String?> signInEmail(String email, String pw) => _run(() async {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email.trim(), password: pw);
      });

  static Future<String?> signUpEmail(String email, String pw) => _run(() async {
        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email.trim(), password: pw);
      });

  static Future<String?> resetPassword(String email) => _run(() async {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      });

  static Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
  }

  /// Méthode de connexion du compte courant.
  static bool get isGoogle =>
      user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
  static bool get isEmail =>
      user?.providerData.any((p) => p.providerId == 'password') ?? false;

  /// Reconnexion Google avant une action sensible.
  static Future<String?> reauthGoogle() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          serverClientId: DefaultFirebaseOptions.webClientId,
        );
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return 'Reconnexion Google impossible : jeton manquant.';
      }
      final cred = GoogleAuthProvider.credential(idToken: idToken);
      await user!.reauthenticateWithCredential(cred);
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) return '';
      return 'Reconnexion Google impossible. Réessayez.';
    }
  }

  /// Reconnexion par mot de passe avant une action sensible.
  static Future<String?> reauthEmail(String pw) => _run(() async {
        final u = user!;
        final cred = EmailAuthProvider.credential(
          email: u.email ?? '',
          password: pw,
        );
        await u.reauthenticateWithCredential(cred);
      });

  /// Supprime le compte Auth (à faire après l'effacement des données).
  static Future<String?> deleteAccount() => _run(() async {
        await user!.delete();
      });

  static Future<String?> _run(Future<void> Function() f) async {
    try {
      await f();
      return null;
    } on FirebaseAuthException catch (e) {
      return _msg(e.code);
    } catch (_) {
      return 'Une erreur est survenue. Réessayez.';
    }
  }

  static String _msg(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Adresse e-mail invalide.';
      case 'user-disabled':
        return 'Ce compte est désactivé.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet e-mail.';
      case 'weak-password':
        return 'Mot de passe trop court (6 caractères minimum).';
      case 'requires-recent-login':
        return 'Reconnexion nécessaire pour cette action.';
      case 'network-request-failed':
        return 'Pas de connexion internet.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard.';
      default:
        return 'Connexion impossible ($code).';
    }
  }
}
