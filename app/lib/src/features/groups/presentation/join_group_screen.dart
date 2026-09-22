/// Rejoindre un groupe : par un lien (`/join/CODE`) ou en tapant le code
/// (`/join`). L'écran montre le groupe avant de rejoindre, puis demande ce
/// que la personne partage — « occupé » présélectionné, jamais imposé.
///
/// Choix non évidents :
/// - l'écran consomme l'invitation retenue par le routeur pendant une
///   connexion ou une inscription : une fois ouvert, on n'y est plus ramené ;
/// - le partage est envoyé AVEC l'adhésion (`join_group`), jamais réglé
///   après coup : le groupe ne voit rien de plus que ce qui a été choisi.
library;

import 'package:agora/src/common_widgets/async_value_widget.dart';
import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/features/groups/application/groups_providers.dart';
import 'package:agora/src/features/groups/domain/group.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/features/groups/presentation/group_labels.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:agora/src/routing/app_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({this.code, super.key});

  /// Code venu d'un lien ; `null` pour le taper.
  final String? code;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _codeField = TextEditingController();
  late String? _code = widget.code?.toUpperCase();
  String? _codeError;
  ShareLevel _share = ShareLevel.busy;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    ref.read(pendingInviteProvider).code = null;
  }

  @override
  void dispose() {
    _codeField.dispose();
    super.dispose();
  }

  void _submitCode() {
    final code = _codeField.text.trim();
    if (!looksLikeInviteCode(code)) {
      setState(
        () => _codeError = AppLocalizations.of(context).errorInvalidInvite,
      );
      return;
    }
    setState(() {
      _codeError = null;
      _code = code.toUpperCase();
    });
  }

  Future<void> _join(InvitePreview preview) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _joining = true);
    try {
      final groupId = await ref
          .read(groupsServiceProvider)
          .join(_code!, _share);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.joinedGroup(preview.name))),
      );
      if (mounted) _openGroup(groupId);
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(messageForError(error, l10n))),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openGroup(String groupId) => context.goNamed(
    AppRoute.group.name,
    pathParameters: {'groupId': groupId},
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final code = _code;
    return Scaffold(
      key: GroupKeys.joinScreen,
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: code == null ? _codeForm(l10n) : _preview(code, l10n),
      ),
    );
  }

  Widget _codeForm(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: GroupKeys.codeField,
        controller: _codeField,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: l10n.inviteCodeLabel,
          errorText: _codeError,
        ),
        onSubmitted: (_) => _submitCode(),
      ),
      const SizedBox(height: 24),
      SubmitButton(
        key: GroupKeys.continueButton,
        label: l10n.continueButton,
        isLoading: false,
        onPressed: _submitCode,
      ),
    ],
  );

  Widget _preview(String code, AppLocalizations l10n) =>
      AsyncValueWidget<InvitePreview>(
        value: ref.watch(invitePreviewProvider(code)),
        data: (preview) {
          final theme = Theme.of(context);
          if (preview.isMember) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.alreadyMember),
                const SizedBox(height: 24),
                FilledButton(
                  key: GroupKeys.openGroup,
                  onPressed: () => _openGroup(preview.groupId),
                  child: Text(l10n.openGroupButton),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.joinGroupQuestion(preview.name),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(l10n.joinMemberCount(preview.memberCount)),
              const SizedBox(height: 24),
              Text(l10n.joinShareQuestion, style: theme.textTheme.titleMedium),
              RadioGroup<ShareLevel>(
                groupValue: _share,
                onChanged: (level) {
                  if (level != null) setState(() => _share = level);
                },
                child: Column(
                  children: [
                    for (final level in ShareLevel.values)
                      RadioListTile<ShareLevel>(
                        key: GroupKeys.shareOption(level),
                        value: level,
                        title: Text(shareLevelLabel(level, l10n)),
                        contentPadding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
              Text(l10n.shareHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              SubmitButton(
                key: GroupKeys.joinButton,
                label: l10n.joinButton,
                isLoading: _joining,
                onPressed: () => _join(preview),
              ),
            ],
          );
        },
      );
}
