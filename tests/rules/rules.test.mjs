import { readFileSync } from 'node:fs';
import { test, before, after } from 'node:test';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  deleteField,
  serverTimestamp,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mypage',
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

// Données de départ écrites comme le ferait le bot (règles ignorées).
async function seed() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice/pages/p1'), { nom: 'A', tokenEnc: 'x', status: 'ok' });
    await setDoc(doc(db, 'users/alice/inbox/c1'), { texte: 't', traite: false });
    await setDoc(doc(db, 'users/alice/stats/s1'), { portee: 1 });
    await setDoc(doc(db, 'users/alice/quota/q1'), { restant: 5 });
    await setDoc(doc(db, 'users/alice/questions/q1'), { texte: '?', reponse: '', etat: 'nouvelle' });
    await setDoc(doc(db, 'users/alice/file/f1'), { action: 'publier' });
  });
}

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('isolation entre utilisateurs', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/pages/p1')));
  await assertFails(getDoc(doc(bob(), 'users/alice/pages/p1')));
  await assertFails(getDoc(doc(anon(), 'users/alice/pages/p1')));
  await assertFails(setDoc(doc(bob(), 'users/alice/profil/x'), { a: 1 }));
});

test('compte : lecture et suppression seulement', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(alice(), 'users/alice')));
  await assertFails(setDoc(doc(alice(), 'users/alice'), { admin: true }));
  await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
});

test('pages : champs autorisés seulement', async () => {
  await seed();
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice/pages/p2'), { nom: 'B', tokenEnc: 'abc', demande: 'connecter' }),
  );
  await assertFails(
    setDoc(doc(alice(), 'users/alice/pages/p3'), { nom: 'B', tokenEnc: 'abc', status: 'ok' }),
  );
  await assertSucceeds(updateDoc(doc(alice(), 'users/alice/pages/p1'), { nom: 'Nouveau' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice/pages/p1'), { status: 'actif' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice/pages/p1'), { quota: 999 }));
  await assertFails(
    setDoc(doc(alice(), 'users/alice/pages/p4'), { nom: 'x'.repeat(201), tokenEnc: 'a' }),
  );
});

test('pages : connexion et déconnexion', async () => {
  await seed();
  const p1 = () => doc(alice(), 'users/alice/pages/p1');
  const vieux = new Date(2000, 0, 1);
  await assertSucceeds(
    setDoc(
      p1(),
      { nom: 'A', tokenEnc: 'abc', demande: 'connecter', maj: serverTimestamp() },
      { merge: true },
    ),
  );
  await assertFails(updateDoc(p1(), { demande: 'deconnecter', maj: serverTimestamp() }));
  await assertSucceeds(
    updateDoc(p1(), {
      tokenEnc: deleteField(),
      demande: 'deconnecter',
      maj: serverTimestamp(),
    }),
  );
  await assertFails(updateDoc(p1(), { demande: 'autre' }));
  await assertFails(updateDoc(p1(), { maj: vieux }));
  await assertFails(
    setDoc(doc(alice(), 'users/alice/pages/p5'), { nom: 'C', tokenEnc: 'a', maj: vieux }),
  );
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice/pages/p6'), {
      nom: 'C',
      tokenEnc: 'a',
      demande: 'connecter',
      maj: serverTimestamp(),
    }),
  );
});

test('inbox : seul le champ traite est modifiable', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/inbox/c1')));
  await assertSucceeds(updateDoc(doc(alice(), 'users/alice/inbox/c1'), { traite: true }));
  await assertFails(updateDoc(doc(alice(), 'users/alice/inbox/c1'), { texte: 'autre' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice/inbox/c1'), { traite: 'oui' }));
  await assertFails(setDoc(doc(alice(), 'users/alice/inbox/c2'), { texte: 'x', traite: false }));
});

test('stats et quota : lecture seule', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/stats/s1')));
  await assertFails(updateDoc(doc(alice(), 'users/alice/stats/s1'), { portee: 99 }));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/quota/q1')));
  await assertFails(updateDoc(doc(alice(), 'users/alice/quota/q1'), { restant: 999 }));
  await assertFails(deleteDoc(doc(alice(), 'users/alice/quota/q1')));
  await assertFails(getDoc(doc(bob(), 'users/alice/quota/q1')));
});

test('profil : lecture et écriture', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/profil/main'), { ton: 'amical' }));
  await assertSucceeds(getDoc(doc(alice(), 'users/alice/profil/main')));
});

test('questions : reponse et etat seulement', async () => {
  await seed();
  await assertSucceeds(
    updateDoc(doc(alice(), 'users/alice/questions/q1'), { reponse: 'oui', etat: 'repondue' }),
  );
  await assertFails(updateDoc(doc(alice(), 'users/alice/questions/q1'), { texte: 'autre' }));
  await assertFails(
    updateDoc(doc(alice(), 'users/alice/questions/q1'), { reponse: 'x'.repeat(2001) }),
  );
  await assertFails(setDoc(doc(alice(), 'users/alice/questions/q2'), { texte: 'x' }));
});

test('file : création et suppression seulement', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(alice(), 'users/alice/file/f2'), { action: 'publier' }));
  await assertFails(updateDoc(doc(alice(), 'users/alice/file/f1'), { action: 'autre' }));
  await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/file/f1')));
  await assertFails(setDoc(doc(bob(), 'users/alice/file/f3'), { action: 'x' }));
});

test('tout le reste est refusé', async () => {
  await seed();
  await assertFails(getDoc(doc(alice(), 'autre/x')));
  await assertFails(setDoc(doc(alice(), 'users/alice/inconnu/x'), { a: 1 }));
  await assertFails(getDoc(doc(anon(), 'users/alice')));
});

test('phase 5 : profil, champs connus et heure du serveur', async () => {
  await seed();
  const p = () => doc(alice(), 'users/alice/profil/p1');
  await assertSucceeds(
    setDoc(p(), { ton: 'neutre', completion: 11, maj: serverTimestamp() }, { merge: true }),
  );
  await assertFails(setDoc(p(), { admin: true }, { merge: true }));
  await assertFails(setDoc(p(), { maj: new Date(2000, 0, 1) }, { merge: true }));
  await assertFails(getDoc(doc(bob(), 'users/alice/profil/p1')));
});

test('phase 5 : proposition protégée', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice/proposition/p1'), {
      ton: 'neutre',
      etat: 'a_valider',
    });
  });
  const p = () => doc(alice(), 'users/alice/proposition/p1');
  await assertSucceeds(getDoc(p()));
  await assertFails(getDoc(doc(bob(), 'users/alice/proposition/p1')));
  await assertSucceeds(setDoc(p(), { decisions: { ton: 'ok' } }, { merge: true }));
  await assertFails(updateDoc(p(), { ton: 'direct' }));
  await assertFails(updateDoc(p(), { etat: 'validee' }));
  await assertSucceeds(updateDoc(p(), { etat: 'redemande' }));
  await assertFails(deleteDoc(doc(bob(), 'users/alice/proposition/p1')));
  await assertSucceeds(deleteDoc(p()));
  await assertSucceeds(setDoc(p(), { etat: 'redemande' }));
  await assertFails(
    setDoc(doc(alice(), 'users/alice/proposition/p2'), { etat: 'redemande', ton: 'direct' }),
  );
});

test('phase 5 : états des questions', async () => {
  await seed();
  const q = () => doc(alice(), 'users/alice/questions/q1');
  await assertSucceeds(updateDoc(q(), { etat: 'passee', reponduLe: serverTimestamp() }));
  await assertFails(updateDoc(q(), { etat: 'ouverte' }));
  await assertFails(updateDoc(q(), { etat: 'passee', reponduLe: new Date(2000, 0, 1) }));
});
