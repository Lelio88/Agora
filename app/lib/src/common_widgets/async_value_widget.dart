/// Affiche une `AsyncValue` : chargement, erreur traduite, ou données.
/// C'est la voie par défaut ; un `.when()` écrit à la main reste l'exception.
library;

import 'package:agora/src/exceptions/app_exception_messages.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({required this.value, required this.data, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => const Center(child: CircularProgressIndicator()),
    error: (error, _) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          messageForError(error, AppLocalizations.of(context)),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
