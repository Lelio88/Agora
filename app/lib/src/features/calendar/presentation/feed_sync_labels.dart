/// Textes de l'état de synchro d'un agenda importé : dernière relecture
/// réussie, relecture en attente, ou la raison du dernier échec.
///
/// Choix non évident : un échec l'emporte sur la date de dernière réussite —
/// l'agenda affiché est peut-être périmé, c'est ce qu'il faut savoir.
library;

import 'package:agora/src/features/calendar/domain/user_calendar.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:intl/intl.dart';

String syncStatusLabel(
  UserCalendar calendar,
  AppLocalizations l10n,
  String locale,
) {
  final error = calendar.syncError;
  if (error != null) return feedSyncErrorLabel(error, l10n);
  final syncedAt = calendar.lastSyncedAt;
  if (syncedAt == null) return l10n.syncPending;
  final format = DateFormat.MMMd(locale).add_Hm();
  return l10n.syncedAt(format.format(syncedAt.toLocal()));
}

String feedSyncErrorLabel(FeedSyncError error, AppLocalizations l10n) =>
    switch (error) {
      FeedSyncError.unreachable => l10n.syncErrorUnreachable,
      FeedSyncError.timeout => l10n.syncErrorTimeout,
      FeedSyncError.notFound => l10n.syncErrorNotFound,
      FeedSyncError.forbidden => l10n.syncErrorForbidden,
      FeedSyncError.httpError => l10n.syncErrorHttp,
      FeedSyncError.tooLarge => l10n.syncErrorTooLarge,
      FeedSyncError.notCalendar => l10n.syncErrorNotCalendar,
      FeedSyncError.blockedAddress => l10n.syncErrorBlockedAddress,
      FeedSyncError.tooManyEvents => l10n.syncErrorTooManyEvents,
      FeedSyncError.unknown => l10n.syncErrorUnknown,
    };
