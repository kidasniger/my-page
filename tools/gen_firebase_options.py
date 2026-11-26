import json, sys
src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src, encoding='utf-8'))
info = d['project_info']
c = d['client'][0]
web = ''
for o in c.get('oauth_client', []):
    if o.get('client_type') == 3:
        web = o.get('client_id', '')
out = f"""// Fichier généré au build à partir de google-services.json. Ne pas modifier.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {{
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: '{c['api_key'][0]['current_key']}',
    appId: '{c['client_info']['mobilesdk_app_id']}',
    messagingSenderId: '{info['project_number']}',
    projectId: '{info['project_id']}',
    storageBucket: '{info.get('storage_bucket', '')}',
  );

  /// Identifiant client Web, requis par Google Sign-In.
  static const String webClientId = '{web}';
}}
"""
open(dst, 'w', encoding='utf-8').write(out)
print('OK web_client_id ' + ('présent' if web else 'ABSENT'))
