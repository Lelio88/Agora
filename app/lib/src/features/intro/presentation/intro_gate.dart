/// L'intro, et ce qu'elle recouvre.
///
/// **Elle empile, elle n'aiguille pas.** [child] — l'app et son routeur — est
/// monté dès le premier frame, *sous* l'animation. La session se relit, le
/// profil et l'agenda partent en requête pendant que l'intro joue : les deux
/// secondes sont retranchées de l'attente au lieu de s'y ajouter. Un `if/else`
/// qui n'aurait monté l'app qu'ensuite aurait fait l'inverse.
///
/// **Elle se joue à chaque lancement**, comme celles de DewDrop et DeckHand, et
/// un appui la saute. On ne la montre pas « une fois par jour » : une ouverture
/// d'application est un moment, et c'est celui où tout est encore froid.
///
/// **Elle s'efface quand le réglage « réduire les animations » est actif**, sans
/// jouer ni son ni image. Ce réglage existe pour les personnes que le mouvement
/// gêne ou rend malades ; une intro qui s'impose quand même est exactement ce
/// qu'il interdit.
///
/// **Elle s'efface en fondu**, pas d'un coup : une disparition sèche se lit
/// comme un défaut d'affichage, et la bascule du fond nuit vers l'app claire
/// est déjà brutale à elle seule.
///
/// Invariant : [child] reste au même endroit de l'arbre du début à la fin.
/// Le retirer de la pile plutôt que de le reconstruire garde son état et ses
/// requêtes en vol — rien ne repart de zéro quand l'intro disparaît.
library;

import 'dart:async';

import 'package:agora/src/device/intro_sound.dart';
import 'package:agora/src/features/intro/presentation/intro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntroGate extends ConsumerStatefulWidget {
  const IntroGate({super.key, required this.child});

  /// L'app, montée sous l'intro dès le premier frame.
  final Widget child;

  @override
  ConsumerState<IntroGate> createState() => _IntroGateState();
}

/// Le fondu de sortie. Assez court pour ne rien ajouter à l'attente, assez
/// long pour qu'on voie l'app se découvrir plutôt qu'apparaître.
const _fondu = Duration(milliseconds: 260);

class _IntroGateState extends ConsumerState<IntroGate> {
  bool _fini = false;
  bool _efface = false;
  bool _demarree = false;
  Timer? _plancher;
  IntroSound? _son;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Le réglage d'accessibilité n'est lisible qu'ici : `initState` n'a pas
    // encore de `MediaQuery`.
    if (_demarree) return;
    _demarree = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _fini = true;
      _efface = true;
      return;
    }
    // En deux temps : `_son = x..play()` appliquerait la cascade au résultat
    // de l'affectation, que Dart voit comme nullable.
    final son = ref.read(introSoundProvider);
    _son = son;
    unawaited(son.play());
    _plancher = Timer(introFloor, _decouvrir);
  }

  @override
  void dispose() {
    _plancher?.cancel();
    unawaited(_son?.dispose());
    super.dispose();
  }

  void _decouvrir() {
    _plancher?.cancel();
    if (mounted && !_fini) setState(() => _fini = true);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (!_efface)
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: _fini ? 0 : 1),
          duration: _fondu,
          // Une fois transparente, l'intro quitte l'arbre : la laisser
          // capterait les appuis destinés à l'app, sans rien montrer.
          onEnd: () {
            if (_fini && mounted) setState(() => _efface = true);
          },
          builder: (context, opacite, enfant) => IgnorePointer(
            ignoring: _fini,
            child: Opacity(opacity: opacite, child: enfant),
          ),
          child: IntroScreen(onTap: _decouvrir),
        ),
    ],
  );
}
