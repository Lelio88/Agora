/// Écran d'un lien de jumelage venu d'une autre app (Arpente), route
/// `/twin` : une **demande** (choisir le groupe Agora à jumeler) ou une
/// **réponse** (relier le groupe dont le jumelage a été lancé d'ici).
///
/// Choix non évidents :
/// - les paramètres sont validés par `parseTwinLink` avant tout affichage :
///   un lien mal formé n'ouvre qu'un message, jamais un bouton ;
/// - seuls les groupes que l'utilisateur gère sont proposés (le serveur ne
///   laisse jumeler que les admins) ; un nouveau groupe, nommé comme le
///   jumeau, est présélectionné ;
/// - une réponse n'est montrée que si elle répond à un jumelage lancé depuis
///   cet appareil (`TwinService.groupFor`), et le groupe concerné est figé à
///   l'ouverture : l'enregistrement oublie la demande, l'écran ne doit pas
///   basculer sur « inconnue » pendant qu'il navigue ;
/// - l'écran consomme le lien retenu par le routeur pendant une connexion ;
/// - si l'autre app ne s'ouvre pas, le jumeau reste enregistré ici et
///   l'écran le dit : relancer depuis le menu du groupe reprend la même
///   invitation.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/device/link_opener.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/application/twin_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/domain/twin.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Choix « un nouveau groupe » (un id de groupe n'est jamais vide).
const _newGroup = '';

/// Longueur maximale d'un nom de groupe (contrainte de la table `groups`).
const _maxNameLength = 60;

class TwinGroupScreen extends ConsumerStatefulWidget {
  const TwinGroupScreen({required this.params, super.key});

  /// Paramètres du lien, tels que reçus.
  final Map<String, String> params;

  @override
  ConsumerState<TwinGroupScreen> createState() => _TwinGroupScreenState();
}

class _TwinGroupScreenState extends ConsumerState<TwinGroupScreen> {
  late final TwinLink? _link = parseTwinLink(widget.params);
  late final _name = TextEditingController(
    text: switch (_link) {
      TwinRequest(:final name) => name ?? '',
      _ => '',
    },
  );

  /// Le groupe Agora auquel répond une réponse, figé à l'ouverture.
  String? _answeredGroup;
  String _target = _newGroup;
  String? _nameError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(pendingTwinProvider).location = null;
    if (_link case final TwinResponse response) {
      _answeredGroup = ref.read(twinServiceProvider).groupFor(response);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: GroupKeys.twinScreen,
      appBar: AppBar(title: Text(l10n.twinTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: switch (_link) {
          null => Text(l10n.errorInvalidTwinLink),
          final TwinRequest request => _request(request, l10n),
          final TwinResponse response => _response(response, l10n),
        },
      ),
    );
  }

  Widget _request(TwinRequest request, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final app = request.app.displayName;
    final name = request.name;
    return AsyncValueWidget<List<MyGroup>>(
      value: ref.watch(myGroupsProvider),
      data: (groups) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name == null
                ? l10n.twinRequestTitleUnnamed(app)
                : l10n.twinRequestTitle(app, name),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(l10n.twinExplain(app)),
          const SizedBox(height: 24),
          Text(l10n.twinChooseGroup, style: theme.textTheme.titleMedium),
          RadioGroup<String>(
            groupValue: _target,
            onChanged: (target) {
              if (target != null) setState(() => _target = target);
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  key: GroupKeys.twinNewGroupOption,
                  value: _newGroup,
                  title: Text(l10n.twinNewGroup),
                  contentPadding: EdgeInsets.zero,
                ),
                for (final group in groups.where((g) => g.role.canManage))
                  RadioListTile<String>(
                    key: GroupKeys.twinGroupOption(group.id),
                    value: group.id,
                    title: Text(group.name),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          if (_target == _newGroup)
            TextField(
              key: GroupKeys.twinNameField,
              controller: _name,
              maxLength: _maxNameLength,
              decoration: InputDecoration(
                labelText: l10n.groupNameLabel,
                errorText: _nameError,
              ),
            ),
          const SizedBox(height: 24),
          SubmitButton(
            key: GroupKeys.twinConfirm,
            label: l10n.twinConfirmButton,
            isLoading: _busy,
            onPressed: () => _accept(request),
          ),
        ],
      ),
    );
  }

  Future<void> _accept(TwinRequest request) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final newName = _name.text.trim();
    final isNew = _target == _newGroup;
    // En caractères, comme char_length côté serveur (pas en unités UTF-16).
    final length = newName.runes.length;
    if (isNew && (length == 0 || length > _maxNameLength)) {
      setState(() => _nameError = l10n.validationGroupName);
      return;
    }
    setState(() {
      _nameError = null;
      _busy = true;
    });
    try {
      final answer = await ref
          .read(twinServiceProvider)
          .accept(
            request,
            groupId: isNew ? null : _target,
            newGroupName: newName,
          );
      final opened = await ref.read(linkOpenerProvider).open(answer.response);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? l10n.twinSaved
                : l10n.twinOpenFailed(request.app.displayName),
          ),
        ),
      );
      if (mounted) _openGroup(answer.groupId);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _response(TwinResponse response, AppLocalizations l10n) {
    final groupId = _answeredGroup;
    if (groupId == null) return Text(l10n.twinResponseUnknown);
    return AsyncValueWidget<MyGroup?>(
      value: ref.watch(myGroupProvider(groupId)),
      data: (group) {
        if (group == null) return Text(l10n.twinResponseUnknown);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.twinResponseQuestion(group.name, response.app.displayName),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            SubmitButton(
              key: GroupKeys.twinLink,
              label: l10n.twinLinkButton,
              isLoading: _busy,
              onPressed: () => _complete(response),
            ),
          ],
        );
      },
    );
  }

  Future<void> _complete(TwinResponse response) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final groupId = await ref.read(twinServiceProvider).complete(response);
      messenger.showSnackBar(SnackBar(content: Text(l10n.twinSaved)));
      if (mounted) _openGroup(groupId);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openGroup(String groupId) => context.goNamed(
    AppRoute.group.name,
    pathParameters: {'groupId': groupId},
  );
}
