/// Écran de consentement d'un assistant IA (route `/oauth/consent`, web) :
/// l'utilisateur connecté accorde ou refuse l'accès que demande un assistant
/// (claude.ai, Claude Code, ChatGPT…), puis l'écran lui rend la main.
///
/// Choix non évidents :
/// - **seul un assistant reconnu par son adresse de retour** peut être
///   autorisé (`recognizeAssistant`). Une demande inconnue est refusée côté
///   serveur, et son adresse n'est jamais suivie ; le nom que le client se
///   donne n'est montré que comme « il se présente comme » ;
/// - un accès déjà accordé fait suivre aussitôt l'adresse que rend le
///   serveur — après le même contrôle ;
/// - rendre la main, c'est quitter l'app **dans le même onglet**
///   (`openInPlace`) : l'assistant attend son code dans cet onglet-là ;
/// - « Ce n'est pas moi » déconnecte (localement) : la demande reste en
///   attente, et la connexion suivante y ramène ;
/// - « Retour à l'accueil » recharge l'app à sa racine : l'adresse de la page
///   porte encore la demande, qu'un rechargement relirait sinon.
library;

import 'dart:async';

import 'package:agora/src/config/web_links.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/assistant/application/assistant_providers.dart';
import 'package:agora/src/features/assistant/domain/assistant.dart';
import 'package:agora/src/features/assistant/presentation/assistant_keys.dart';
import 'package:agora/src/features/assistant/presentation/assistant_labels.dart';
import 'package:agora/src/features/auth/application/auth_providers.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({required this.authorizationId, super.key});

  /// `null` si l'adresse n'en porte pas (lien tronqué).
  final String? authorizationId;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

enum _Stage { deciding, sending, handedOver, failed, refused }

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  var _stage = _Stage.deciding;

  /// Hôte d'une demande inconnue, refusée sans être suivie.
  String? _unknownHost;

  /// Une décision automatique (accès déjà accordé, assistant inconnu) a été
  /// prise : ne pas la reprendre.
  bool _settled = false;

  Future<void> _handOver(Uri url) async {
    if (recognizeAssistant(url.toString()) == null) {
      setState(() {
        _stage = _Stage.refused;
        _unknownHost = url.host;
      });
      return;
    }
    final opened = await ref.read(linkOpenerProvider).openInPlace(url);
    if (!mounted) return;
    setState(() => _stage = opened ? _Stage.handedOver : _Stage.failed);
  }

  Future<void> _decide({required bool approve}) async {
    final id = widget.authorizationId!;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _stage = _Stage.sending);
    try {
      final service = ref.read(assistantServiceProvider);
      final back = approve ? await service.approve(id) : await service.deny(id);
      if (!mounted) return;
      if (back == null) {
        setState(() => _stage = _Stage.refused);
        return;
      }
      await _handOver(back);
    } on Exception catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
      setState(() => _stage = _Stage.deciding);
    }
  }

  /// Assistant inconnu : refusé côté serveur, son adresse n'est pas suivie.
  Future<void> _refuseUnknown(String id, String redirectUri) async {
    final service = ref.read(assistantServiceProvider);
    try {
      await service.deny(id);
    } on Exception {
      service.forget();
    }
    if (!mounted) return;
    setState(() {
      _stage = _Stage.refused;
      _unknownHost = Uri.tryParse(redirectUri)?.host ?? '';
    });
  }

  void _settle(ConsentRequest request, String id) {
    if (_settled) return;
    switch (request) {
      case ConsentAlreadyGiven(:final redirectUrl):
        _settled = true;
        ref.read(assistantServiceProvider).forget();
        unawaited(_handOver(redirectUrl));
      case ConsentToDecide(:final redirectUri)
          when recognizeAssistant(redirectUri) == null:
        _settled = true;
        unawaited(_refuseUnknown(id, redirectUri));
      case ConsentToDecide():
        break;
    }
  }

  Future<void> _goHome() async {
    ref.read(assistantServiceProvider).forget();
    final base = ref.read(webBaseUrlProvider);
    if (base == null) {
      context.goNamed(AppRoute.home.name);
      return;
    }
    await ref.read(linkOpenerProvider).openInPlace(base.resolve('/'));
  }

  @override
  void initState() {
    super.initState();
    final id = widget.authorizationId;
    if (id == null) return;
    // Fermé avec l'écran ; dès la première lecture, même déjà en cache.
    ref.listenManual(consentRequestProvider(id), (_, next) {
      if (next case AsyncData(:final value)) {
        // Hors de la construction : l'issue change l'état de l'écran.
        scheduleMicrotask(() {
          if (mounted) _settle(value, id);
        });
      } else if (next.hasError) {
        ref.read(assistantServiceProvider).forget();
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = widget.authorizationId;
    return Scaffold(
      key: ConsentKeys.screen,
      appBar: AppBar(
        title: Text(l10n.consentTitle),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          // Une colonne défilante plutôt qu'une ListView : tout l'écran existe
          // dès l'ouverture, boutons compris (formulaire court).
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _body(context, l10n, id),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, AppLocalizations l10n, String? id) {
    if (id == null) {
      return _outcome(l10n.errorConsentExpired, ConsentKeys.failed);
    }
    switch (_stage) {
      case _Stage.handedOver:
        return [Text(l10n.consentHandedOver, key: ConsentKeys.handedOver)];
      case _Stage.failed:
        return _outcome(l10n.consentHandOverFailed, ConsentKeys.failed);
      case _Stage.refused:
        final host = _unknownHost;
        return _outcome(
          host == null
              ? l10n.consentDenied
              : l10n.consentUnknownAssistant(host),
          ConsentKeys.refused,
        );
      case _Stage.deciding || _Stage.sending:
        break;
    }
    final request = ref.watch(consentRequestProvider(id));
    if (request case AsyncData(
      value: ConsentToDecide(
        :final redirectUri,
        :final clientName,
        :final email,
      ),
    )) {
      // Inconnu : _settle le refuse ; en attendant, rien à décider.
      if (recognizeAssistant(redirectUri) case final assistant?) {
        return _decision(context, l10n, assistant, clientName, email);
      }
    }
    if (request case AsyncError(:final error)) {
      return _outcome(messageForError(error, l10n), ConsentKeys.failed);
    }
    return const [Center(child: CircularProgressIndicator())];
  }

  List<Widget> _outcome(String message, Key key) => [
    Text(message, key: key),
    const SizedBox(height: 24),
    Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        key: ConsentKeys.home,
        onPressed: _goHome,
        child: Text(AppLocalizations.of(context).consentHome),
      ),
    ),
  ];

  List<Widget> _decision(
    BuildContext context,
    AppLocalizations l10n,
    KnownAssistant assistant,
    String clientName,
    String email,
  ) {
    final text = Theme.of(context).textTheme;
    final label = assistantLabel(assistant, l10n);
    final busy = _stage == _Stage.sending;
    return [
      Text(l10n.consentQuestion(label), style: text.headlineSmall),
      if (clientName.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(l10n.consentPresentsAs(clientName)),
      ],
      const SizedBox(height: 24),
      Text(l10n.consentCanTitle, style: text.titleSmall),
      _Bullet(l10n.consentCanRead),
      _Bullet(l10n.consentCanSlots),
      _Bullet(l10n.consentCanWrite),
      const SizedBox(height: 12),
      Text(l10n.consentCannotTitle, style: text.titleSmall),
      _Bullet(l10n.consentCannot),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l10n.consentWarning),
        ),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: Text(l10n.consentAccount(email))),
          TextButton(
            key: ConsentKeys.notMe,
            onPressed: busy
                ? null
                : () => ref.read(authRepositoryProvider).signOut(),
            child: Text(l10n.consentNotMe),
          ),
        ],
      ),
      const SizedBox(height: 16),
      FilledButton(
        key: ConsentKeys.approve,
        onPressed: busy ? null : () => _decide(approve: true),
        child: Text(l10n.consentApprove),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        key: ConsentKeys.deny,
        onPressed: busy ? null : () => _decide(approve: false),
        child: Text(l10n.consentDeny),
      ),
    ];
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('•  '),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
