/// L'écran d'introduction : trois agendas se posent, viennent s'accoler, et la
/// seule bande que personne n'occupe s'allume.
///
/// **C'est la traduction de `tools/mockups/agora_intro.html`**, pas une
/// réinvention : le mouvement s'y est réglé à l'œil, les nombres en viennent.
/// Toute retouche se fait d'abord là-bas, où une seconde d'essai coûte un
/// rafraîchissement de page au lieu d'une recompilation.
///
/// **[battues] est jumelle de `BATTUES` dans `tools/sounds/gen_intro_jingle.py`.**
/// Les six gestes de l'image et les six notes du jingle sont les mêmes ;
/// déplacer l'un sans l'autre désynchronise l'intro, et cela ne s'entend qu'à
/// l'oreille.
///
/// **Le fond est nuit alors que l'app est claire, et c'est voulu** : il
/// prolonge l'icône et l'écran de démarrage Android, tous deux sur ce fond.
/// L'app s'ouvre en clair juste après, quand l'intro s'efface.
///
/// Invariant : l'intro ne retient jamais personne. Un appui la saute,
/// `IntroGate` la retire de toute façon, et le son ne peut pas la bloquer.
library;

import 'dart:math' as math;

import 'package:agora/src/features/intro/presentation/intro_keys.dart';
import 'package:agora/src/localization/app_localizations.dart';
import 'package:flutter/material.dart';

/// Les six gestes, en secondes depuis la première note.
const battues = [0.0, 0.30, 0.60, 0.90, 1.10, 1.40];

/// L'écran s'ouvre un peu avant la première note, pour que le mouvement ne
/// commence pas sur une image déjà figée.
///
/// Le jingle, lui, part dès que l'écran se monte : le plugin audio met à peu
/// près ce temps-là à rendre la main, et les deux se rejoignent.
const _avant = 0.18;

/// Durée de l'animation : la dernière note, plus la montée du mot.
const introAnimation = Duration(milliseconds: 2150);

/// Ce que `IntroGate` laisse à l'écran. Cent millisecondes de plus que
/// l'animation, pour qu'on en voie la dernière image au lieu de la quitter sur
/// sa fin.
const introFloor = Duration(milliseconds: 2250);

const _nuitHaut = Color(0xFF1A1B3A);
const _nuitBas = Color(0xFF262850);

/// Le périwinkle de l'icône : sur fond nuit, l'indigo de la marque
/// disparaîtrait, et une bande blanche se confondrait avec les fûts.
const _bande = Color(0xFF7C8CFF);

/// Les trois membres, aux couleurs de `common_widgets/palette.dart`, et leurs
/// créneaux pris en fraction de la hauteur de colonne.
///
/// **La bande 0,52 → 0,66 est libre chez les trois** : c'est elle qui s'allume
/// à la cinquième battue. Déplacer un bloc sans vérifier cette intersection
/// casse la démonstration.
const _agendas = [
  (Color(0xFF1E88E5), [(0.06, 0.24), (0.66, 0.80)]),
  (Color(0xFF43A047), [(0.12, 0.32), (0.72, 0.92)]),
  (Color(0xFFE53935), [(0.38, 0.52), (0.78, 0.94)]),
];
const _libre = (0.52, 0.66);

// Scène de référence, en unités logiques. Le peintre la met à l'échelle de
// l'écran réel ; ces nombres, eux, ne bougent pas — ce sont ceux de la
// maquette.
const _sceneL = 360.0, _sceneH = 780.0;
const _colL = 76.0, _colH = 420.0;
const _ecartDebut = 112.0, _ecartFin = _colL;
const _haut = 140.0;

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onTap});

  /// Appelée quand quelqu'un appuie pour sauter l'attente.
  final VoidCallback onTap;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: introAnimation,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).appTitle,
      button: true,
      child: GestureDetector(
        key: IntroKeys.screen,
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: Size.infinite,
            painter: _IntroPainter(
              seconde: _controller.value * introAnimation.inMilliseconds / 1000,
              texte: _mot(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Le nom, mis en page une fois par image plutôt qu'à chaque trait.
  TextPainter _mot(BuildContext context) {
    final peintre = TextPainter(
      text: TextSpan(
        text: AppLocalizations.of(context).appTitle,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 50,
          fontWeight: FontWeight.w600,
          letterSpacing: 3,
        ),
      ),
      textDirection: Directionality.of(context),
    );
    peintre.layout();
    return peintre;
  }
}

double _sortieCubique(double x) => 1 - math.pow(1 - x, 3).toDouble();

double _douxCubique(double x) =>
    x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3).toDouble() / 2;

/// Avancement d'un geste : 0 avant, 1 après, adouci entre les deux.
double _phase(
  double t,
  double debut,
  double duree, {
  double Function(double) courbe = _sortieCubique,
}) => courbe(((t - debut) / duree).clamp(0.0, 1.0));

class _IntroPainter extends CustomPainter {
  const _IntroPainter({required this.seconde, required this.texte});

  /// Temps écoulé depuis l'ouverture de l'écran.
  final double seconde;
  final TextPainter texte;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_nuitHaut, _nuitBas],
        ).createShader(Offset.zero & size),
    );

    // La scène garde ses proportions et se centre : sur un écran plus large ou
    // plus court, le dessin rétrécit au lieu de se déformer.
    final echelle = math.min(size.width / _sceneL, size.height / _sceneH);
    canvas.save();
    canvas.translate(
      (size.width - _sceneL * echelle) / 2,
      (size.height - _sceneH * echelle) / 2,
    );
    canvas.scale(echelle);

    final t = math.max(0.0, seconde - _avant);
    _agendasEtBande(canvas, t);
    _nom(canvas, t);
    canvas.restore();
  }

  void _agendasEtBande(Canvas canvas, double t) {
    final fusion = _phase(t, battues[3], 0.42, courbe: _douxCubique);
    const centre = _sceneL / 2;

    for (var i = 0; i < _agendas.length; i++) {
      final entree = _phase(t, battues[i], 0.30);
      if (entree <= 0) continue;

      final (couleur, blocs) = _agendas[i];
      final ecart = _ecartDebut + (_ecartFin - _ecartDebut) * fusion;
      final x = centre + (i - 1) * ecart - _colL / 2;
      final y = _haut + (1 - entree) * -80;

      // Une fois accolés, les coins qui se touchent s'arrondissent moins :
      // trois cartes séparées deviennent un bloc.
      final rayon = Radius.circular(18 - fusion * 10);
      final fut = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, _colL, _colH),
        rayon,
      );
      canvas.drawRRect(
        fut,
        Paint()..color = Colors.white.withValues(alpha: entree),
      );

      final encre = Paint()..color = couleur.withValues(alpha: entree);
      const marge = 9.0;
      for (final (a, b) in blocs) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              x + marge,
              y + a * _colH,
              _colL - marge * 2,
              (b - a) * _colH,
            ),
            const Radius.circular(7),
          ),
          encre,
        );
      }
    }

    final eclat = _phase(t, battues[4], 0.30);
    if (eclat <= 0) return;

    // La bande traverse les trois colonnes : le créneau n'appartient à
    // personne, il est commun.
    const large = _ecartFin * 2 + _colL;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        centre - large / 2,
        _haut + _libre.$1 * _colH,
        large,
        (_libre.$2 - _libre.$1) * _colH,
      ),
      const Radius.circular(12),
    );
    // Un halo, pas un simple aplat : c'est ce qui la sépare d'un bloc occupé.
    // Discret, sinon il bave sur les fûts blancs et brouille leurs bords.
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _bande.withValues(alpha: eclat * 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * eclat),
    );
    canvas.drawRRect(rect, Paint()..color = _bande.withValues(alpha: eclat));

    final coche = _phase(t, battues[4] + 0.10, 0.26);
    if (coche <= 0) return;
    final cy = rect.center.dy;
    canvas.drawPath(
      Path()
        ..moveTo(centre - 15, cy)
        ..lineTo(centre - 5, cy + 10)
        ..lineTo(centre + 16, cy - 11),
      Paint()
        ..color = _nuitHaut.withValues(alpha: coche)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _nom(Canvas canvas, double t) {
    final mot = _phase(t, battues[5], 0.55);
    if (mot <= 0) return;
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: mot),
    );
    texte.paint(
      canvas,
      Offset((_sceneL - texte.width) / 2, _haut + _colH + 60 + (1 - mot) * 14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IntroPainter ancien) => ancien.seconde != seconde;
}
