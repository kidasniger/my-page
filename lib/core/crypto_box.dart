import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pointycastle/export.dart';

/// Chiffrement hybride du jeton avant son envoi dans Firestore.
/// - AES-256-GCM : clé aléatoire de 32 octets, nonce de 12 octets, tag de 16 octets.
/// - RSA-OAEP SHA-256 (MGF1 SHA-256) : chiffre la clé AES avec la clé publique
///   embarquée (assets/pub.pem).
/// L'appli sait seulement chiffrer : seule la clé privée du bot peut déchiffrer.
/// Ne jamais journaliser l'entrée ni la sortie de ce module.
class CryptoBox {
  static const String alg = 'RSA-OAEP-256+A256GCM';
  static const String _asset = 'assets/pub.pem';
  static RSAPublicKey? _cached;

  /// Charge (une seule fois) la clé publique embarquée.
  static Future<RSAPublicKey> loadPublicKey() async {
    final c = _cached;
    if (c != null) return c;
    final pem = await rootBundle.loadString(_asset);
    final k = parsePublicKeyPem(pem);
    _cached = k;
    return k;
  }

  /// Chiffre avec la clé publique embarquée.
  static Future<String> encryptWithBundledKey(String plain) async {
    return encrypt(plain, await loadPublicKey());
  }

  /// Renvoie un JSON : v, alg, ek (clé AES chiffrée), iv (nonce), ct
  /// (texte chiffré) et tag, chacun en base64.
  static String encrypt(String plain, RSAPublicKey pub) {
    final key = _randomBytes(32);
    final iv = _randomBytes(12);
    try {
      final gcm = GCMBlockCipher(AESEngine())
        ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
      final out = gcm.process(Uint8List.fromList(utf8.encode(plain)));
      final ct = out.sublist(0, out.length - 16);
      final tag = out.sublist(out.length - 16);

      final oaep = OAEPEncoding.withSHA256(RSAEngine())
        ..init(
          true,
          ParametersWithRandom(
            PublicKeyParameter<RSAPublicKey>(pub),
            _fortuna(),
          ),
        );
      final ek = oaep.process(key);

      return jsonEncode({
        'v': 1,
        'alg': alg,
        'ek': base64Encode(ek),
        'iv': base64Encode(iv),
        'ct': base64Encode(ct),
        'tag': base64Encode(tag),
      });
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  /// Lit une clé publique PEM au format SubjectPublicKeyInfo (BEGIN PUBLIC KEY).
  static RSAPublicKey parsePublicKeyPem(String pem) {
    final b64 = pem
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    final der = base64Decode(b64);
    final spki = _Der(der).read(0x30);
    final r = _Der(spki);
    r.read(0x30); // identifiant d'algorithme
    final bits = r.read(0x03);
    if (bits.isEmpty || bits[0] != 0) {
      throw const FormatException('Clé publique invalide.');
    }
    final rsa = _Der(_Der(Uint8List.sublistView(bits, 1)).read(0x30));
    final n = _toBigInt(rsa.read(0x02));
    final e = _toBigInt(rsa.read(0x02));
    if (n.bitLength < 2048) {
      throw const FormatException('Clé publique trop courte.');
    }
    return RSAPublicKey(n, e);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static SecureRandom _fortuna() {
    return FortunaRandom()..seed(KeyParameter(_randomBytes(32)));
  }

  static BigInt _toBigInt(Uint8List bytes) {
    var r = BigInt.zero;
    for (final x in bytes) {
      r = (r << 8) | BigInt.from(x);
    }
    return r;
  }
}

/// Lecteur DER minimal (séquences, entiers, chaînes de bits).
class _Der {
  final Uint8List _b;
  int _p = 0;
  _Der(this._b);

  Uint8List read(int tag) {
    if (_p + 2 > _b.length || _b[_p] != tag) {
      throw const FormatException('Clé publique invalide.');
    }
    _p++;
    var len = _b[_p++];
    if ((len & 0x80) != 0) {
      final k = len & 0x7f;
      if (k == 0 || k > 4 || _p + k > _b.length) {
        throw const FormatException('Clé publique invalide.');
      }
      len = 0;
      for (var i = 0; i < k; i++) {
        len = (len << 8) | _b[_p++];
      }
    }
    if (_p + len > _b.length) {
      throw const FormatException('Clé publique invalide.');
    }
    final out = Uint8List.sublistView(_b, _p, _p + len);
    _p += len;
    return out;
  }
}
