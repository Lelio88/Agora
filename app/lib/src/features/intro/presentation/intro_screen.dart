/// L'écran d'introduction : la semaine se couvre, tout s'efface, et il reste
/// le créneau que personne n'avait pris — qui s'ouvre pour porter le nom.
///
/// **C'est la traduction de `tools/mockups/agora_intro.html`**, pas une
/// réinvention : le mouvement s'y est réglé à l'œil, les nombres en viennent.
/// Toute retouche se fait d'abord là-bas, où une seconde d'essai coûte un
/// rafraîchissement de page au lieu d'une recompilation.
///
/// **Ce que l'animation raconte.** Trois membres remplissent la semaine, une
/// vague par note du jingle. Une case — et une seule — n'est remplie par
/// personne : le créneau commun. Quand la semaine se vide, elle est déjà là ;
/// on n'a rien à désigner, l'œil l'a trouvée pendant le remplissage. C'est
/// « Créneaux communs » en deux secondes et sans un mot.
///
/// **[battues] est jumelle de `BATTUES` dans `tools/sounds/gen_intro_jingle.py`.**
/// Les six gestes de l'image et les six notes du jingle sont les mêmes ;
/// déplacer l'un sans l'autre désynchronise l'intro, et cela ne s'entend qu'à
/// l'oreille.
///
/// **Les durées sont celles de DewDrop et de DeckHand**, au millième près :
/// 2200 ms d'animation, 2300 ms avant de découvrir l'app. Les trois
/// applications partagent cette grammaire, et une intro qui durerait plus
/// longtemps ici se remarquerait chez les autres.
///
/// **Le fond est nuit alors que l'app est claire, et c'est voulu** : il
/// prolonge l'icône et l'écran de démarrage Android. L'app s'ouvre en clair
/// juste après, quand l'intro s'efface.
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
/// commence pas sur une image déjà en place.
///
/// Le jingle, lui, part dès que l'écran se monte : le plugin audio met à peu
/// près ce temps-là à rendre la main, et les deux se rejoignent.
const _avant = 0.18;

/// Durée de l'animation. Identique à DewDrop et DeckHand.
const introAnimation = Duration(milliseconds: 2200);

/// Ce que `IntroGate` laisse à l'écran : cent millisecondes de plus que
/// l'animation, pour qu'on en voie la dernière image au lieu de la quitter
/// sur sa fin.
const introFloor = Duration(milliseconds: 2300);

const _nuitHaut = Color(0xFF1A1B3A);
const _nuitBas = Color(0xFF262850);

/// Le périwinkle de l'icône. Sur fond nuit, l'indigo de la marque
/// disparaîtrait, et du blanc se confondrait avec le reste.
const _accent = Color(0xFF7C8CFF);

/// Les trois membres, aux couleurs de `common_widgets/palette.dart`.
const _membres = [Color(0xFF1E88E5), Color(0xFF43A047), Color(0xFFE53935)];

// Scène de référence, en unités logiques. Le peintre la met à l'échelle de
// l'écran réel ; ces nombres, eux, ne bougent pas — ce sont ceux de la
// maquette.
const _sceneL = 360.0, _sceneH = 780.0;
const _cx = _sceneL / 2, _cy = 340.0;

// Sept colonnes : une semaine. Cinq rangs, et la case libre au centre exact —
// elle n'a donc rien à rejoindre quand elle s'ouvre.
const _cols = 7, _rangs = 5;
const _large = 36.0, _hauteur = 44.0, _ex = 6.0, _ey = 6.0;
const _libreCol = 3, _libreRang = 2;

const _largeTotal = _cols * _large + (_cols - 1) * _ex;
const _hautTotal = _rangs * _hauteur + (_rangs - 1) * _ey;

/// Taille de la police du nom. Le rectangle qui le porte se dimensionne sur sa
/// largeur mesurée : un nom plus long ne déborde pas de son créneau.
const _tailleMot = 46.0;

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
    final direction = Directionality.of(context);
    final titre = AppLocalizations.of(context).appTitle;
    return Semantics(
      label: titre,
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
              mot: _mesure(titre, _tailleMot, _nuitHaut, direction, 2),
              jours: [
                for (final jour in _joursDe(context))
                  _mesure(jour, 15, Colors.white, direction, 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Les initiales des sept jours, dans la langue de l'app et en commençant
  /// par le lundi — comme les vues d'agenda.
  List<String> _joursDe(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return [
      for (var i = 0; i < 7; i++)
        l10n.narrowWeekdays[(l10n.firstDayOfWeekIndex + i) % 7],
    ];
  }

  /// Un texte mis en page une fois par image plutôt qu'à chaque trait.
  TextPainter _mesure(
    String texte,
    double taille,
    Color couleur,
    TextDirection direction,
    double espacement,
  ) {
    final peintre = TextPainter(
      text: TextSpan(
        text: texte,
        style: TextStyle(
          color: couleur,
          fontSize: taille,
          fontWeight: FontWeight.w600,
          letterSpacing: espacement,
        ),
      ),
      textDirection: direction,
    )..layout();
    return peintre;
  }
}

double _sortieCubique(double x) => 1 - math.pow(1 - x, 3).toDouble();

double _douxCubique(double x) =>
    x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3).toDouble() / 2;

/// Dépassement franc puis retour.
///
/// **Elle rend un epsilon positif en zéro** (2e-16, l'arithmétique flottante) :
/// tester `rebond(x) > 0` pour savoir si un geste a commencé allumerait donc
/// la case dès la première image. On teste le temps, jamais cette valeur.
double _rebond(double x) {
  const c1 = 1.70158, c3 = c1 + 1;
  final u = x - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}

/// Avancement d'un geste : 0 avant, 1 après, adouci entre les deux.
double _phase(
  double t,
  double debut,
  double duree, {
  double Function(double) courbe = _sortieCubique,
}) => courbe(((t - debut) / duree).clamp(0.0, 1.0));

/// À qui appartient la case (c, r).
///
/// Déterministe, jamais tiré au hasard : une intro qui change à chaque
/// lancement ne se règle pas, et deux captures d'écran ne se comparent plus.
int _membre(int c, int r) => (c * 3 + r * 5 + c % 2) % 3;

class _IntroPainter extends CustomPainter {
  const _IntroPainter({
    required this.seconde,
    required this.mot,
    required this.jours,
  });

  /// Temps écoulé depuis l'ouverture de l'écran.
  final double seconde;
  final TextPainter mot;
  final List<TextPainter> jours;

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
    final efface = _phase(t, battues[3], 0.42, courbe: _douxCubique);

    // La grille respire : un rapprochement d'un pour cent pendant
    // l'effacement, qu'on sent sans le voir.
    canvas.save();
    final souffle = 1 + 0.012 * efface;
    canvas.translate(_cx, _cy);
    canvas.scale(souffle);
    canvas.translate(-_cx, -_cy);

    final x0 = _cx - _largeTotal / 2;
    final y0 = _cy - _hautTotal / 2;

    _initialesDesJours(canvas, t, x0, y0, efface);
    _semaine(canvas, t, x0, y0);
    _creneau(canvas, t, x0, y0);

    canvas.restore();
    canvas.restore();
  }

  void _initialesDesJours(
    Canvas canvas,
    double t,
    double x0,
    double y0,
    double efface,
  ) {
    final alpha = 0.45 * _phase(t, 0, 0.30) * (1 - efface);
    if (alpha <= 0) return;
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    for (var c = 0; c < jours.length && c < _cols; c++) {
      jours[c].paint(
        canvas,
        Offset(
          x0 + c * (_large + _ex) + (_large - jours[c].width) / 2,
          y0 - 30,
        ),
      );
    }
    canvas.restore();
  }

  void _semaine(Canvas canvas, double t, double x0, double y0) {
    for (var c = 0; c < _cols; c++) {
      for (var r = 0; r < _rangs; r++) {
        final x = x0 + c * (_large + _ex);
        final y = y0 + r * (_hauteur + _ey);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, _large, _hauteur),
          const Radius.circular(6),
        );

        if (c == _libreCol && r == _libreRang) {
          // **Le creux.** Aucun fond : la case garde la couleur de la nuit, et
          // un contour interrompu dit « libre » sans qu'on ait à l'expliquer.
          // Un aplat pâle se lisait comme une quatrième couleur de membre.
          final pret = _phase(t, 0.10, 0.30);
          if (pret <= 0) continue;
          canvas.drawPath(
            _pointille(Path()..addRRect(rect)),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.40 * pret)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
          continue;
        }

        final qui = _membre(c, r);
        // Trois vagues : chaque membre remplit ses cases sur sa note.
        final entree = _phase(
          t,
          battues[qui] + ((c + r) % 4) * 0.035,
          0.26,
          courbe: _douxCubique,
        );
        if (entree <= 0) continue;

        // L'effacement balaie de gauche à droite.
        final sorti = _phase(t, battues[3] + (c / _cols) * 0.26, 0.20);
        final alpha = entree * (1 - sorti) * 0.92;
        if (alpha <= 0) continue;
        canvas.drawRRect(
          rect,
          Paint()..color = _membres[qui].withValues(alpha: alpha),
        );
      }
    }
  }

  /// Le créneau commun s'ouvre jusqu'à porter le nom.
  ///
  /// L'intro ne se termine donc pas *à côté* de ce que l'app sait faire, elle
  /// se termine dedans.
  void _creneau(Canvas canvas, double t, double x0, double y0) {
    // On teste le temps, pas la valeur de la courbe : voir [_rebond].
    if (t < battues[4]) return;
    final k = _phase(t, battues[4], 0.50, courbe: _rebond).clamp(0.0, 1.1);

    final largeFinale = math.max(214.0, mot.width + 64);
    const hauteFinale = 90.0;
    final l = _large + (largeFinale - _large) * k;
    final h = _hauteur + (hauteFinale - _hauteur) * k;
    final cx = x0 + _libreCol * (_large + _ex) + _large / 2;
    final cy = y0 + _libreRang * (_hauteur + _ey) + _hauteur / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: l, height: h),
      Radius.circular(6 + 10 * math.min(1.0, k)),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = _accent.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14 * math.min(1.0, k)),
    );
    canvas.drawRRect(rect, Paint()..color = _accent);

    final apparait = _phase(t, battues[5], 0.45);
    if (apparait <= 0) return;
    // Nuit sur périwinkle : le couple de couleurs de l'icône, inversé.
    canvas.saveLayer(
      null,
      Paint()..color = Colors.white.withValues(alpha: apparait),
    );
    mot.paint(
      canvas,
      Offset(cx - mot.width / 2, cy - mot.height / 2 + (1 - apparait) * 6),
    );
    canvas.restore();
  }

  /// Découpe un tracé en tirets : Flutter ne sait pas pointiller un trait.
  Path _pointille(Path source, {double tiret = 5, double espace = 4}) {
    final sortie = Path();
    for (final metrique in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metrique.length) {
        final fin = math.min(distance + tiret, metrique.length);
        sortie.addPath(metrique.extractPath(distance, fin), Offset.zero);
        distance = fin + espace;
      }
    }
    return sortie;
  }

  @override
  bool shouldRepaint(_IntroPainter ancien) => ancien.seconde != seconde;
}
