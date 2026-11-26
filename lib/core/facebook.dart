import 'dart:convert';

import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;

/// Erreur affichable à l'utilisateur. Ne contient jamais de jeton.
class FbError implements Exception {
  final String message;
  const FbError(this.message);
  @override
  String toString() => message;
}

/// Page gérée par l'utilisateur : identifiant et nom seulement.
class FbPage {
  final String id;
  final String name;
  const FbPage(this.id, this.name);
}

/// Connexion de la Page : permissions, jeton utilisateur, liste des Pages.
/// Le jeton reste en mémoire le temps d'être chiffré. Ne jamais le journaliser.
class Facebook {
  static const List<String> permissions = [
    'pages_show_list',
    'pages_read_engagement',
    'pages_manage_posts',
    'pages_manage_engagement',
    'pages_messaging',
  ];

  static const String _host = 'graph.facebook.com';
  static const String _version = 'v26.0';

  /// Ouvre la connexion native. Renvoie le jeton utilisateur,
  /// ou null si l'utilisateur a annulé.
  static Future<String?> login() async {
    final LoginResult res;
    try {
      res = await FacebookAuth.instance.login(permissions: permissions);
    } catch (_) {
      throw const FbError('Connexion impossible. Réessayez.');
    }
    if (res.status == LoginStatus.cancelled) return null;
    if (res.status == LoginStatus.operationInProgress) {
      throw const FbError('Une connexion est déjà en cours.');
    }
    final token = res.accessToken?.tokenString;
    if (res.status != LoginStatus.success || token == null || token.isEmpty) {
      throw const FbError('Connexion refusée. Réessayez.');
    }
    return token;
  }

  /// Permissions demandées mais non accordées.
  static Future<List<String>> missingPermissions(String token) async {
    final body = await _get(token, 'me/permissions', const {});
    final granted = <String>{};
    for (final e in _list(body['data'])) {
      if (e is Map && e['status'] == 'granted') {
        granted.add('${e['permission']}');
      }
    }
    return permissions.where((p) => !granted.contains(p)).toList();
  }

  /// Pages gérées. Le champ access_token n'est volontairement pas demandé.
  static Future<List<FbPage>> pages(String token) async {
    final out = <FbPage>[];
    String? after;
    for (var i = 0; i < 10; i++) {
      final body = await _get(token, 'me/accounts', {
        'fields': 'id,name',
        'limit': '100',
        'after': ?after,
      });
      for (final e in _list(body['data'])) {
        if (e is Map && e['id'] != null) {
          out.add(FbPage('${e['id']}', '${e['name'] ?? e['id']}'));
        }
      }
      final paging = body['paging'];
      if (paging is! Map || paging['next'] == null) break;
      final cursors = paging['cursors'];
      after = cursors is Map ? cursors['after'] as String? : null;
      if (after == null) break;
    }
    return out;
  }

  /// Oublie la session et le jeton conservés par le SDK sur le téléphone.
  static Future<void> logout() async {
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
  }

  static List<dynamic> _list(dynamic v) => v is List ? v : const <dynamic>[];

  static Future<Map<String, dynamic>> _get(
    String token,
    String path,
    Map<String, String> query,
  ) async {
    final http.Response r;
    try {
      r = await http.get(
        Uri.https(_host, '/$_version/$path', query),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const FbError('Pas de connexion internet.');
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = null;
    }
    if (r.statusCode == 200 && body is Map<String, dynamic>) return body;
    final err = body is Map ? body['error'] : null;
    final code = err is Map ? err['code'] : null;
    if (code == 190) {
      throw const FbError('Session expirée. Reconnectez-vous.');
    }
    throw FbError('Lecture des Pages impossible (${code ?? r.statusCode}).');
  }
}
