/// [LinkOpener] adossé au plugin url_launcher (Android et web).
///
/// Choix non évidents :
///   - `externalApplication` : la page légale s'ouvre dans le navigateur du
///     téléphone, pas dans une vue interne. Une vue interne donnerait
///     l'illusion que le texte fait partie de l'app, sans barre d'adresse
///     pour vérifier d'où il vient ;
///   - sur le web, `_blank` garde l'app ouverte dans son onglet : revenir en
///     arrière depuis la page légale rechargerait l'app et sa session.
///
/// Un plugin absent (test d'intégration, plateforme sans navigateur) rend
/// `false` au lieu de lever : ne pas pouvoir ouvrir une page ne doit jamais
/// interrompre ce que la personne était en train de faire.
library;

import 'package:agora/src/device/link_opener.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

final class UrlLauncherLinkOpener implements LinkOpener {
  const UrlLauncherLinkOpener();

  @override
  Future<bool> open(Uri url) async {
    try {
      return await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
