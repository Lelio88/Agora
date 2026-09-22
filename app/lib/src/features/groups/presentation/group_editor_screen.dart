/// Création ou renommage d'un groupe : nom et description. Comme les autres
/// éditeurs, il ne parle pas au serveur et renvoie un [GroupDraft].
library;

import 'package:agora/src/common_widgets/submit_button.dart';
import 'package:agora/src/features/groups/presentation/group_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

const _maxNameLength = 60;
const _maxDescriptionLength = 500;

final class GroupDraft {
  const GroupDraft({required this.name, this.description});

  final String name;
  final String? description;
}

class GroupEditorScreen extends StatefulWidget {
  const GroupEditorScreen({this.initialName, super.key});

  /// Nom actuel pour un renommage ; `null` pour une création.
  final String? initialName;

  static Future<GroupDraft?> show(
    BuildContext context, {
    String? initialName,
  }) => Navigator.of(context).push<GroupDraft>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => GroupEditorScreen(initialName: initialName),
    ),
  );

  @override
  State<GroupEditorScreen> createState() => _GroupEditorScreenState();
}

class _GroupEditorScreenState extends State<GroupEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  final _description = TextEditingController();

  bool get _isCreation => widget.initialName == null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      GroupDraft(
        name: _name.text,
        description: _isCreation ? _description.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: GroupKeys.editor,
      appBar: AppBar(
        title: Text(_isCreation ? l10n.newGroupTitle : l10n.renameGroup),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: GroupKeys.name,
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.groupNameLabel),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  return trimmed.isEmpty || trimmed.length > _maxNameLength
                      ? l10n.validationGroupName
                      : null;
                },
              ),
              if (_isCreation) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: GroupKeys.description,
                  controller: _description,
                  decoration: InputDecoration(
                    labelText: l10n.groupDescriptionLabel,
                  ),
                  maxLength: _maxDescriptionLength,
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
              const SizedBox(height: 24),
              SubmitButton(
                key: GroupKeys.save,
                label: _isCreation ? l10n.createButton : l10n.saveButton,
                isLoading: false,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
