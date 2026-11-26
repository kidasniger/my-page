import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';

import '../core/auth.dart';
import '../core/store.dart';
import 'login.dart';
import 'onboarding.dart';

/// Porte d'entrée : parcours de démarrage (une seule fois), puis connexion,
/// tant qu'aucun utilisateur n'est connecté. Aucun de ces écrans n'affiche
/// la barre de navigation, car ils vivent hors de la coquille principale.
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _key = 'onb_done';
  bool? _onbDone;

  @override
  void initState() {
    super.initState();
    _loadFlag();
  }

  Future<void> _loadFlag() async {
    var done = true;
    try {
      done = (await Store.get(_key).timeout(const Duration(seconds: 5))) == '1';
    } catch (_) {
      // coffre indisponible : on passe directement à la connexion
    }
    if (mounted) setState(() => _onbDone = done);
  }

  void _finishOnboarding() {
    setState(() => _onbDone = true);
    unawaited(
      Store.set(_key, '1')
          .timeout(const Duration(seconds: 5))
          .catchError((Object _) {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Auth.changes,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting ||
            _onbDone == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.data != null) return widget.child;
        if (_onbDone == false) {
          return OnboardingScreen(onDone: _finishOnboarding);
        }
        return const LoginScreen();
      },
    );
  }
}
