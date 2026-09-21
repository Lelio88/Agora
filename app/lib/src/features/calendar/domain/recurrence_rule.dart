/// Règle de répétition d'un rdv, dans le sous-ensemble de la RFC 5545 que
/// l'éditeur sait représenter : fréquence, intervalle, jours de la semaine,
/// fin par date ou par nombre.
///
/// L'app ne déplie jamais une règle : c'est le rôle du worker, seule
/// implémentation des RRULE du projet. Elle se contente de la sérialiser
/// (`toRRule`) et de la relire (`parse`). Une règle importée d'un agenda iCal
/// qui sort de ce sous-ensemble se lit `null` : l'éditeur la montre comme
/// « règle avancée », sans la réécrire.
library;

enum Frequency { daily, weekly, monthly, yearly }

final class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    this.interval = 1,
    this.weekdays = const {},
    this.until,
    this.count,
  }) : assert(interval >= 1, 'interval must be at least 1'),
       assert(
         until == null || count == null,
         'until and count exclude one another',
       );

  final Frequency frequency;
  final int interval;

  /// Jours de la semaine (`DateTime.monday` … `DateTime.sunday`), pour une
  /// fréquence hebdomadaire.
  final Set<int> weekdays;
  final DateTime? until;
  final int? count;

  static const _dayCodes = {
    DateTime.monday: 'MO',
    DateTime.tuesday: 'TU',
    DateTime.wednesday: 'WE',
    DateTime.thursday: 'TH',
    DateTime.friday: 'FR',
    DateTime.saturday: 'SA',
    DateTime.sunday: 'SU',
  };

  static final _allowedParts = {'FREQ', 'INTERVAL', 'BYDAY', 'UNTIL', 'COUNT'};

  /// Sérialise en RRULE, sans le préfixe `RRULE:`.
  String toRRule() {
    final parts = ['FREQ=${frequency.name.toUpperCase()}'];
    if (interval > 1) parts.add('INTERVAL=$interval');
    if (weekdays.isNotEmpty) {
      final sorted = weekdays.toList()..sort();
      parts.add('BYDAY=${sorted.map((day) => _dayCodes[day]).join(',')}');
    }
    if (until case final until?) parts.add('UNTIL=${_formatUtc(until)}');
    if (count case final count?) parts.add('COUNT=$count');
    return parts.join(';');
  }

  /// Relit une RRULE ; `null` si elle sort du sous-ensemble représentable.
  static RecurrenceRule? parse(String rrule) {
    final values = <String, String>{};
    for (final part in rrule.split(';')) {
      final separator = part.indexOf('=');
      if (separator <= 0) return null;
      final key = part.substring(0, separator).toUpperCase();
      if (!_allowedParts.contains(key)) return null;
      values[key] = part.substring(separator + 1);
    }
    final frequency = Frequency.values
        .where((f) => f.name.toUpperCase() == values['FREQ'])
        .firstOrNull;
    if (frequency == null) return null;

    final interval = int.tryParse(values['INTERVAL'] ?? '1');
    if (interval == null || interval < 1) return null;

    final weekdays = <int>{};
    for (final code in values['BYDAY']?.split(',') ?? const <String>[]) {
      final day = _dayCodes.entries
          .where((entry) => entry.value == code)
          .firstOrNull
          ?.key;
      if (day == null) return null;
      weekdays.add(day);
    }

    final until = values['UNTIL'] == null ? null : _parseUtc(values['UNTIL']!);
    if (values.containsKey('UNTIL') && until == null) return null;
    final count = values['COUNT'] == null
        ? null
        : int.tryParse(values['COUNT']!);
    if (values.containsKey('COUNT') && count == null) return null;
    if (until != null && count != null) return null;

    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      weekdays: weekdays,
      until: until,
      count: count,
    );
  }

  static String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static DateTime? _parseUtc(String value) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})Z?)?$',
    ).firstMatch(value);
    if (match == null) return null;
    int part(int index) => int.parse(match.group(index) ?? '0');
    return DateTime.utc(part(1), part(2), part(3), part(4), part(5), part(6));
  }

  RecurrenceRule copyWith({
    Frequency? frequency,
    int? interval,
    Set<int>? weekdays,
    DateTime? Function()? until,
    int? Function()? count,
  }) => RecurrenceRule(
    frequency: frequency ?? this.frequency,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    until: until == null ? this.until : until(),
    count: count == null ? this.count : count(),
  );

  @override
  bool operator ==(Object other) =>
      other is RecurrenceRule && other.toRRule() == toRRule();

  @override
  int get hashCode => toRRule().hashCode;
}
