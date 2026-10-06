/// [Sharer] adossé au plugin share_plus : la feuille de partage d'Android.
///
/// Un plugin absent (test d'intégration) ne fait rien plutôt que de lever :
/// ne pas pouvoir partager ne doit pas interrompre l'écran.
library;

import 'package:agora/src/device/sharer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

final class SharePlusSharer implements Sharer {
  const SharePlusSharer();

  @override
  bool get isAvailable => !kIsWeb;

  @override
  Future<void> share(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: subject));
    } on MissingPluginException {
      return;
    }
  }
}
