import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_page/core/crypto_box.dart';
import 'package:pointycastle/export.dart';

/// Clé de TEST générée en mémoire : jamais la vraie clé privée du bot.
SecureRandom _rnd() {
  final r = Random.secure();
  final seed = Uint8List.fromList(List<int>.generate(32, (_) => r.nextInt(256)));
  return FortunaRandom()..seed(KeyParameter(seed));
}

/// Déchiffrement côté test uniquement (le bot fera l'équivalent en Python).
String _decrypt(String box, RSAPrivateKey priv) {
  final m = jsonDecode(box) as Map<String, dynamic>;
  final oaep = OAEPEncoding.withSHA256(RSAEngine())
    ..init(false, PrivateKeyParameter<RSAPrivateKey>(priv));
  final key = oaep.process(base64Decode(m['ek'] as String));
  final iv = base64Decode(m['iv'] as String);
  final ct = base64Decode(m['ct'] as String);
  final tag = base64Decode(m['tag'] as String);
  final gcm = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final plain = gcm.process(Uint8List.fromList([...ct, ...tag]));
  return utf8.decode(plain);
}

void main() {
  late RSAPublicKey pub;
  late RSAPrivateKey priv;

  setUpAll(() {
    final gen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        _rnd(),
      ));
    final pair = gen.generateKeyPair();
    pub = pair.publicKey as RSAPublicKey;
    priv = pair.privateKey as RSAPrivateKey;
  });

  test('chiffre puis déchiffre avec la clé de test', () {
    const jeton = 'JETON-DE-TEST-0123456789-éàç';
    final box = CryptoBox.encrypt(jeton, pub);
    expect(box.contains(jeton), isFalse);
    final m = jsonDecode(box) as Map<String, dynamic>;
    expect(m['alg'], CryptoBox.alg);
    expect(base64Decode(m['iv'] as String).length, 12);
    expect(base64Decode(m['tag'] as String).length, 16);
    expect(base64Decode(m['ek'] as String).length, 256);
    expect(_decrypt(box, priv), jeton);
  });

  test('deux chiffrements du même jeton diffèrent', () {
    final a = CryptoBox.encrypt('meme-jeton', pub);
    final b = CryptoBox.encrypt('meme-jeton', pub);
    expect(a == b, isFalse);
  });

  test('un tag modifié est rejeté', () {
    final m = jsonDecode(CryptoBox.encrypt('jeton', pub)) as Map<String, dynamic>;
    final tag = base64Decode(m['tag'] as String);
    tag[0] ^= 0x01;
    m['tag'] = base64Encode(tag);
    expect(() => _decrypt(jsonEncode(m), priv), throwsA(anything));
  });

  test('la clé publique embarquée se lit (2048 bits minimum)', () {
    final pem = File('assets/pub.pem').readAsStringSync();
    final k = CryptoBox.parsePublicKeyPem(pem);
    expect(k.modulus!.bitLength, greaterThanOrEqualTo(2048));
    expect(CryptoBox.encrypt('x', k).isNotEmpty, isTrue);
  });
}
