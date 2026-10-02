/// Parcours de bout en bout d'une répétition de mise en ligne, à travers le
/// Caddy de la répétition (vhost de prod transposé en HTTP local).
///
/// Lancé par rehearse.sh, avec le .env de la répétition en argument (la clé
/// anon y est lue, jamais écrite ailleurs). Crée deux comptes jetables et les
/// supprime par delete_my_account, qui fait partie du parcours vérifié.
///
/// Choix non évidents :
///   - flux d'authentification implicite : le client Dart pur n'a pas de
///     stockage pour le PKCE, et le serveur vérifie le même code OTP ;
///   - trois secondes entre l'abonnement Realtime et l'insertion : Realtime
///     branche l'abonnement aux changements juste après avoir répondu au
///     « join », une insertion immédiate le précéderait.
///
///   dart run --packages=app/.dart_tool/package_config.json \
///     deploy/rehearsal/check.dart deploy/rehearsal/.work/.env
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

const _api = 'http://localhost:8481';
const _web = 'http://localhost:8480';
const _mailpit = 'http://127.0.0.1:8482';
const _password = 'Rehearsal42';

var _failures = 0;

void _check(String label, bool ok, [Object? detail]) {
  if (!ok) _failures++;
  stdout.writeln('${ok ? 'OK' : 'KO'}  $label${detail == null ? '' : ' — $detail'}');
}

/// Dernier e-mail reçu par [to] dans Mailpit : (sujet, texte).
Future<(String, String)> _lastMail(String to) async {
  for (var i = 0; i < 20; i++) {
    final list = jsonDecode(
        (await http.get(Uri.parse('$_mailpit/api/v1/search?query=to:$to'))).body);
    final messages = list['messages'] as List;
    if (messages.isNotEmpty) {
      final id = messages.first['ID'];
      final msg =
          jsonDecode((await http.get(Uri.parse('$_mailpit/api/v1/message/$id'))).body);
      return (msg['Subject'] as String, msg['Text'] as String);
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('aucun e-mail pour $to');
}

Future<SupabaseClient> _signUp(String key, String email, String name) async {
  final client = SupabaseClient(_api, key,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit));
  await client.auth.signUp(email: email, password: _password, data: {
    'display_name': name,
    'locale': 'fr',
    'timezone': 'Europe/Paris',
  });
  final (subject, text) = await _lastMail(email);
  _check('e-mail de confirmation ($name)',
      subject == 'Agora — code de confirmation · confirmation code', subject);
  _check('gabarit d\'Agora lu par URL, en français ($name)',
      text.contains('Saisis ce code dans Agora'));
  final code = RegExp(r'\b(\d{6})\b').firstMatch(text)!.group(1)!;
  await client.auth.verifyOTP(type: OtpType.signup, email: email, token: code);
  _check('code vérifié, session ouverte ($name)', client.auth.currentSession != null);
  return client;
}

Future<void> _checkCors(String key) async {
  final preflight = await http.Client().send(
      http.Request('OPTIONS', Uri.parse('$_api/auth/v1/signup'))
        ..headers.addAll({
          'Origin': _web,
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'apikey,authorization,content-type,x-client-info',
        }));
  _check('contrôle préalable CORS : 204', preflight.statusCode == 204, preflight.statusCode);
  _check('… qui autorise apikey',
      (preflight.headers['access-control-allow-headers'] ?? '').contains('apikey'));
  _check('… pour la seule origine de l\'app',
      preflight.headers['access-control-allow-origin'] == _web);

  final anonRead = await http.get(Uri.parse('$_api/rest/v1/events?select=id'),
      headers: {'apikey': key, 'Authorization': 'Bearer $key', 'Origin': _web});
  _check('sans session, les rdv sont illisibles',
      anonRead.statusCode == 401 || anonRead.statusCode == 403, anonRead.statusCode);
  _check('une seule origine CORS sur une réponse de PostgREST',
      anonRead.headers['access-control-allow-origin'] == _web);
  // Sans cet en-tête exposé, le client Supabase lit les erreurs de GoTrue au
  // mauvais format et l'app n'affiche plus que « une erreur est survenue ».
  _check(
      "la version d'API de Supabase est lisible du navigateur",
      (anonRead.headers['access-control-expose-headers'] ?? '')
          .toLowerCase()
          .contains('x-supabase-api-version'));
}

/// Appel brut d'un point d'entrée de GoTrue à travers Caddy :
/// (statut, corps, durée).
Future<(int, String, Duration)> _auth(
    String key, String path, Map<String, Object?> body) async {
  final watch = Stopwatch()..start();
  final res = await http.post(Uri.parse('$_api/auth/v1/$path'),
      headers: {'apikey': key, 'Content-Type': 'application/json', 'Origin': _web},
      body: jsonEncode(body));
  return (res.statusCode, res.body, watch.elapsed);
}

/// La passerelle d'auth (worker/authgate) : rien, ni la réponse ni sa durée,
/// ne dit si une adresse a un compte. [existing] est le compte confirmé de
/// [alice] ; [other], celui d'un autre.
Future<void> _checkAuthGate(
    String key, SupabaseClient alice, String existing, String other) async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final unknown = 'personne.$stamp@rehearsal.local';
  const emailDelay = Duration(milliseconds: 1400);
  const signInFloor = Duration(milliseconds: 750);

  // Deux demandes de suite : GoTrue seul répondrait 429 à la seconde pour
  // un compte (un e-mail par minute et par adresse), 200 pour une inconnue.
  final answers = <(int, String)>{};
  var fastest = const Duration(days: 1);
  Future<void> probe(String path, Map<String, Object?> body) async {
    final (status, text, elapsed) = await _auth(key, path, body);
    answers.add((status, text));
    if (elapsed < fastest) fastest = elapsed;
  }

  for (final email in [existing, unknown, existing, unknown]) {
    await probe('recover', {'email': email});
    await probe('resend', {'type': 'signup', 'email': email});
  }
  await probe('signup', {'email': existing, 'password': _password});
  await probe('signup', {'email': 'nouveau.$stamp@rehearsal.local', 'password': _password});
  _check('inscription, mot de passe oublié, renvoi : une seule réponse',
      answers.length == 1 && answers.single == (200, '{}'), answers);
  _check('… toujours au même délai', fastest >= emailDelay, fastest);

  final (variantStatus, _, _) = await _auth(key, 'recover/', {'email': existing});
  _check('une variante d\'écriture n\'atteint pas GoTrue en direct', variantStatus == 404,
      variantStatus);

  final otpAnswers = <(int, String)>{};
  for (final email in [existing, unknown]) {
    final (status, text, _) =
        await _auth(key, 'otp', {'email': email, 'create_user': false});
    otpAnswers.add((status, text));
  }
  _check('lien magique coupé, même réponse pour tous',
      otpAnswers.length == 1 && otpAnswers.single.$1 == 422, otpAnswers);

  final signIns = <(int, String)>{};
  var fastestSignIn = const Duration(days: 1);
  for (final email in [existing, unknown]) {
    final (status, text, elapsed) = await _auth(
        key, 'token?grant_type=password', {'email': email, 'password': 'Mauvais42'});
    signIns.add((status, text));
    if (elapsed < fastestSignIn) fastestSignIn = elapsed;
  }
  _check('mauvais mot de passe ou adresse inconnue : même refus',
      signIns.length == 1 && signIns.single.$1 == 400, signIns);
  _check('… au même délai', fastestSignIn >= signInFloor, fastestSignIn);

  // Un compte connecté ne sonde pas les adresses en essayant d'en changer.
  final headers = {
    'apikey': key,
    'Authorization': 'Bearer ${alice.auth.currentSession!.accessToken}',
    'Content-Type': 'application/json',
    'Origin': _web,
  };
  final changes = <(int, String)>{};
  for (final email in [other, unknown]) {
    final res = await http.put(Uri.parse('$_api/auth/v1/user'),
        headers: headers, body: jsonEncode({'email': email}));
    changes.add((res.statusCode, res.body));
  }
  _check("changement d'adresse refusé, même réponse pour tous",
      changes.length == 1 && changes.single.$1 == 422, changes);
  final update = await http.put(Uri.parse('$_api/auth/v1/user'),
      headers: headers, body: jsonEncode({'data': {'display_name': 'Alice'}}));
  _check('le reste de la mise à jour du compte passe', update.statusCode == 200,
      update.statusCode);
}

Future<void> _checkGroupFlow(SupabaseClient alice, SupabaseClient bob) async {
  final groupId = await alice.rpc<String>('create_group', params: {'p_name': 'Répétition'});
  final code = await alice.rpc<String>('create_invite', params: {'p_group_id': groupId});
  await bob.rpc<String>('join_group', params: {'p_code': code, 'p_share_level': 'details'});
  _check('groupe créé et rejoint', true);

  final myCalendar =
      (await bob.from('calendars').select('id').isFilter('group_id', null)).first['id'];

  final received = Completer<Map<String, dynamic>>();
  final subscribed = Completer<void>();
  final channel = bob.channel('rehearsal').onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'events',
    callback: (payload) {
      if (!received.isCompleted) received.complete(payload.newRecord);
    },
  );
  channel.subscribe((status, _) {
    if (status == RealtimeSubscribeStatus.subscribed && !subscribed.isCompleted) {
      subscribed.complete();
    }
  });
  await subscribed.future.timeout(const Duration(seconds: 15));
  _check('abonnement Realtime établi', true);
  await Future<void>.delayed(const Duration(seconds: 3));

  final now = DateTime.now().toUtc();
  final start = DateTime.utc(now.year, now.month, now.day + 1, 18);
  await bob.from('events').insert({
    'calendar_id': myCalendar,
    'title': 'Escalade',
    'starts_at': start.toIso8601String(),
    'ends_at': start.add(const Duration(hours: 2)).toIso8601String(),
    'all_day': false,
    'timezone': 'Europe/Paris',
    'rrule': 'FREQ=WEEKLY',
  });
  final record = await received.future.timeout(const Duration(seconds: 15));
  _check('insertion reçue en temps réel', record['title'] == 'Escalade');
  await bob.removeChannel(channel);

  final range = {
    'p_from': start.subtract(const Duration(days: 1)).toIso8601String(),
    'p_to': start.add(const Duration(days: 20)).toIso8601String(),
  };
  var occurrences = <dynamic>[];
  for (var i = 0; i < 30 && occurrences.length < 3; i++) {
    final agenda = await bob.rpc<List<dynamic>>('my_agenda', params: range);
    occurrences = agenda.where((r) => r['title'] == 'Escalade').toList();
    if (occurrences.length < 3) await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  _check('le worker a déplié la série', occurrences.length >= 3, '${occurrences.length} occurrences');

  final groupAgenda =
      await alice.rpc<List<dynamic>>('group_agenda', params: {'p_group_id': groupId, ...range});
  _check('agenda du groupe résolu par la règle de vie privée',
      groupAgenda.where((r) => r['title'] == 'Escalade').length >= 3);
}

Future<void> main(List<String> args) async {
  final env = File(args.single).readAsLinesSync();
  final key = env.firstWhere((l) => l.startsWith('ANON_KEY=')).substring('ANON_KEY='.length);
  final stamp = DateTime.now().millisecondsSinceEpoch;

  await _checkCors(key);
  final alice = await _signUp(key, 'alice.$stamp@rehearsal.local', 'Alice');
  final bob = await _signUp(key, 'bob.$stamp@rehearsal.local', 'Bob');
  try {
    await _checkAuthGate(
        key, alice, 'alice.$stamp@rehearsal.local', 'bob.$stamp@rehearsal.local');
    await _checkGroupFlow(alice, bob);
  } finally {
    for (final client in [bob, alice]) {
      try {
        await client.rpc<void>('delete_my_account');
      } on Object catch (e) {
        _check('suppression du compte', false, e);
      }
      await client.dispose();
    }
    _check('comptes de répétition supprimés', true);
  }
  stdout.writeln(_failures == 0 ? '\nRépétition verte.' : '\n$_failures contrôle(s) en échec.');
  exit(_failures == 0 ? 0 : 1);
}
