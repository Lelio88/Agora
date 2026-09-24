/// [IntroSound] adossé au plugin audioplayers (Android et web).
///
/// Choix non évidents :
///   - `ReleaseMode.stop` : le jingle ne boucle pas et le lecteur reste en
///     place, prêt pour le lancement suivant sans recharger l'asset ;
///   - `AudioContext` en mode « média » : le son se tait quand le téléphone
///     est en silencieux, se met en pause si une musique joue déjà, et ne
///     coupe pas un appel. Un écran de lancement n'a aucune raison de passer
///     devant ce que la personne écoute ;
///   - toute erreur est avalée. Un plugin absent (test d'intégration, machine
///     sans carte son), un asset introuvable ou un canal audio occupé ne
///     doivent jamais retenir quelqu'un devant l'animation.
library;

import 'package:agora/src/device/intro_sound.dart';
import 'package:audioplayers/audioplayers.dart';

final class AudioPlayersIntroSound implements IntroSound {
  AudioPlayersIntroSound();

  final _lecteur = AudioPlayer();
  bool _pret = false;

  @override
  Future<void> play() async {
    try {
      if (!_pret) {
        await _lecteur.setReleaseMode(ReleaseMode.stop);
        await _lecteur.setAudioContext(
          AudioContext(
            android: const AudioContextAndroid(
              usageType: AndroidUsageType.media,
              contentType: AndroidContentType.music,
              audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: const {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
        _pret = true;
      }
      await _lecteur.play(AssetSource('audio/agora_intro.mp3'));
    } on Object {
      // Voir le commentaire de tête : un jingle muet est un détail, une
      // exception au lancement ne l'est pas.
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _lecteur.dispose();
    } on Object {
      // Idem : rien à rattraper au moment où l'écran disparaît.
    }
  }
}
