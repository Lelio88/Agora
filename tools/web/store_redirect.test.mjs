// Tests de app/web/store_redirect.js (logique pure, sans navigateur).
// Lancer : node --test tools/web/store_redirect.test.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { test } from 'node:test';

const require = createRequire(import.meta.url);
const { playStoreRedirect, PLAY_STORE_URL } = require('../../app/web/store_redirect.js');

const ANDROID =
  'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';
const IPHONE =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 ' +
  '(KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
const DESKTOP =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

const CODE = 'ABCDEFGH';

const aller = (hash, { ua = ANDROID, pathname = '/', search = '' } = {}) =>
  playStoreRedirect(ua, pathname, search, hash);

test('la fiche visée est celle de app.agora', () => {
  assert.equal(PLAY_STORE_URL, 'https://play.google.com/store/apps/details?id=app.agora');
});

test('un lien de partage ouvert sous Android renvoie vers le Play Store', () => {
  for (const hash of [
    `#/join/${CODE}`,
    `#/profile/${CODE}`,
    '#/twin?de=abc&nom=Camille',
    '#/event?de=abc&titre=Cin%C3%A9&debut=2026-10-20T18:00',
    '#/twin',
    '#/event',
  ]) {
    assert.equal(aller(hash), PLAY_STORE_URL, hash);
  }
});

test('ni iOS ni ordinateur : la version web reste la seule voie', () => {
  assert.equal(aller(`#/join/${CODE}`, { ua: IPHONE }), null);
  assert.equal(aller(`#/join/${CODE}`, { ua: DESKTOP }), null);
});

test('un fragment qui n’est pas un lien de partage reste sur le web', () => {
  for (const hash of ['', '#', '#/', '#/sign-in', '#/groups', '#/oauth/consent', '#/joint/x']) {
    assert.equal(aller(hash), null, hash);
  }
});

test('un code d’invitation ou de profil implausible reste sur le web', () => {
  // Alphabet des codes : ni 0, 1, I, O ; huit caractères exactement.
  for (const hash of [
    '#/join/ABC',
    '#/join/ABCDEFGHI',
    '#/join/ABCDEFG0',
    '#/join/ABCDEFGO',
    `#/join/${CODE}?x=1`,
    '#/profile/',
    '#/profile/ABCDEFG1',
  ]) {
    assert.equal(aller(hash), null, hash);
  }
});

test('un code en minuscules est plausible, comme dans le routeur', () => {
  assert.equal(aller('#/join/abcdefgh'), PLAY_STORE_URL);
});

test('seule la racine du site est concernée', () => {
  assert.equal(aller(`#/join/${CODE}`, { pathname: '/legal/confidentialite.html' }), null);
  assert.equal(aller(`#/join/${CODE}`, { pathname: '/captcha.html' }), null);
  assert.equal(aller(`#/join/${CODE}`, { pathname: '' }), PLAY_STORE_URL);
});

test('?web reste une porte de sortie vers la version web', () => {
  assert.equal(aller(`#/join/${CODE}`, { search: '?web=1' }), null);
  assert.equal(aller(`#/join/${CODE}`, { search: '?web' }), null);
  assert.equal(aller(`#/join/${CODE}`, { search: '?autre=1' }), PLAY_STORE_URL);
});
