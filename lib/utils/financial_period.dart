/// One budgeting cycle: `[start, endExclusive)`.
///
/// Users can set a `startingDayOfMonth` so the cycle follows their payday
/// rather than the calendar. That makes "this month" ambiguous, and screens
/// used to resolve it themselves by filtering on the *calendar* month the
/// current date happens to sit in. Before the starting day that names the wrong
/// cycle — on August 4 with a starting day of 10, the live cycle is July 10 to
/// August 9, but a calendar-month filter asks for the one beginning August 10
/// and finds nothing. Totals, budgets, projections and AI inputs then disagree
/// with each other.
///
/// So the period is resolved once, here, and every screen shares the answer.
class FinancialPeriod {
  const FinancialPeriod._(this.start, this.endExclusive, this.startingDay);

  /// The cycle that [moment] falls inside.
  factory FinancialPeriod.containing(DateTime moment, int startingDay) {
    final day = _clampStartingDay(startingDay);
    final start = moment.day >= day
        ? DateTime(moment.year, moment.month, day)
        : DateTime(moment.year, moment.month - 1, day);
    return FinancialPeriod._(start, _addMonth(start, day), day);
  }

  /// The cycle that begins on [startingDay] of [month]/[year].
  ///
  /// For picking a past cycle. Prefer [containing] for "now" — passing the
  /// current calendar month here is the bug this class exists to prevent.
  factory FinancialPeriod.startingIn(int year, int month, int startingDay) {
    final day = _clampStartingDay(startingDay);
    final start = DateTime(year, month, day);
    return FinancialPeriod._(start, _addMonth(start, day), day);
  }

  /// Inclusive first instant.
  final DateTime start;

  /// Exclusive last instant. Half-open, so no timestamp falls between two
  /// adjacent periods and none belongs to both.
  final DateTime endExclusive;

  final int startingDay;

  /// A day-of-month past the length of some month would roll over into the
  /// next one (day 31 in February), silently shifting the cycle.
  static int _clampStartingDay(int day) => day.clamp(1, 28);

  /// `DateTime(y, m + 1, d)` already normalises a December start into January.
  static DateTime _addMonth(DateTime from, int day) =>
      DateTime(from.year, from.month + 1, day);

  bool contains(DateTime moment) =>
      !moment.isBefore(start) && moment.isBefore(endExclusive);

  FinancialPeriod get previous => FinancialPeriod._(
    DateTime(start.year, start.month - 1, startingDay),
    start,
    startingDay,
  );

  FinancialPeriod get next =>
      FinancialPeriod._(endExclusive, _addMonth(endExclusive, startingDay),
          startingDay);

  /// Shifted by [months]; negative goes back.
  FinancialPeriod shifted(int months) => FinancialPeriod.startingIn(
    start.year,
    start.month + months,
    startingDay,
  );

  /// Length in whole days. Varies with month length, which is why projections
  /// must read it here instead of assuming 30 or `DateTime(y, m + 1, 0).day`.
  int get totalDays => endExclusive.difference(start).inDays;

  /// Days of this period already spent as of [moment], at least 1 so callers
  /// can divide by it. A [moment] past the end returns the full length.
  int daysElapsed(DateTime moment) {
    if (!moment.isAfter(start)) return 1;
    if (!moment.isBefore(endExclusive)) return totalDays;
    return moment.difference(start).inDays + 1;
  }

  /// Days left including the day [moment] sits in, at least 1.
  int daysRemaining(DateTime moment) =>
      (totalDays - daysElapsed(moment) + 1).clamp(1, totalDays);

  /// Label for the cycle, e.g. 'August 2026'.
  ///
  /// A cycle spanning two calendar months is named after the one it starts in,
  /// matching how people refer to a pay period.
  String get label => '${_monthNames[start.month - 1]} ${start.year}';

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  bool operator ==(Object other) =>
      other is FinancialPeriod &&
      other.start == start &&
      other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(start, endExclusive);

  @override
  String toString() => 'FinancialPeriod($start -> $endExclusive)';
}
