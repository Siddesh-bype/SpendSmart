import 'dart:math' as math;

/// Pacing status classification for the current billing cycle.
enum PacingStatus {
  onTrack,
  caution,
  overBudget,
}

/// Structured pacing analysis result.
class PacingAnalysis {
  final double spendSoFar;
  final double budget;
  final int daysElapsed;
  final int totalDays;
  final int daysRemaining;
  final double projectedMonthEnd;
  final double dailySafeToSpend;
  final double burnRate;
  final double deltaFromBudget;
  final PacingStatus status;

  const PacingAnalysis({
    required this.spendSoFar,
    required this.budget,
    required this.daysElapsed,
    required this.totalDays,
    required this.daysRemaining,
    required this.projectedMonthEnd,
    required this.dailySafeToSpend,
    required this.burnRate,
    required this.deltaFromBudget,
    required this.status,
  });

  bool get isOverBudget => status == PacingStatus.overBudget;
}

/// Health score rating tiers.
enum HealthScoreTier {
  excellent,
  good,
  fair,
  needsAttention,
}

/// Structured financial health report.
class HealthScoreReport {
  final int score;
  final HealthScoreTier tier;
  final String summary;
  final List<String> actionableRecommendations;

  const HealthScoreReport({
    required this.score,
    required this.tier,
    required this.summary,
    required this.actionableRecommendations,
  });
}

/// Optimized settle-up transaction between two participants.
class SettlementTransfer {
  final String from;
  final String to;
  final double amount;

  const SettlementTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });
}

/// Pure Dart financial calculation and optimization engine.
///
/// Houses all mathematical models, burn-rate projections, health scoring,
/// and debt-graph settlement algorithms with zero framework or UI dependencies.
class FinancialCalculationEngine {
  const FinancialCalculationEngine._();

  /// Calculates spending pacing, linear projection, burn-rate index,
  /// and remaining daily safe-to-spend allowance.
  static PacingAnalysis calculatePacing({
    required double spendSoFar,
    required double budget,
    required int daysElapsed,
    required int totalDays,
  }) {
    final validTotalDays = math.max(1, totalDays);
    final validElapsed = math.max(1, math.min(daysElapsed, validTotalDays));
    final remainingDays = math.max(1, validTotalDays - validElapsed);

    final safeSpend = spendSoFar > 0 ? spendSoFar : 0.0;
    final projected = (safeSpend / validElapsed) * validTotalDays;

    final remainingBudget = math.max(0.0, budget - safeSpend);
    final dailySafe = remainingBudget / remainingDays;

    final plannedDailyRate = budget > 0 ? (budget / validTotalDays) : 0.0;
    final actualDailyRate = safeSpend / validElapsed;
    final burnRate = plannedDailyRate > 0 ? (actualDailyRate / plannedDailyRate) : 1.0;

    final delta = budget > 0 ? (budget - projected) : 0.0;

    PacingStatus status;
    if (budget <= 0) {
      status = PacingStatus.onTrack;
    } else if (safeSpend > budget || burnRate > 1.25) {
      status = PacingStatus.overBudget;
    } else if (burnRate > 1.05) {
      status = PacingStatus.caution;
    } else {
      status = PacingStatus.onTrack;
    }

    return PacingAnalysis(
      spendSoFar: safeSpend,
      budget: budget,
      daysElapsed: validElapsed,
      totalDays: validTotalDays,
      daysRemaining: remainingDays,
      projectedMonthEnd: projected,
      dailySafeToSpend: dailySafe,
      burnRate: burnRate,
      deltaFromBudget: delta,
      status: status,
    );
  }

  /// Evaluates financial posture and produces an objective 0–100 health score.
  ///
  /// Criteria:
  /// - Budget pacing adherence (0–40 pts)
  /// - Burn rate consistency (0–25 pts)
  /// - Discretionary vs essential concentration (0–20 pts)
  /// - Recurring commitment ratio (0–15 pts)
  static HealthScoreReport evaluateHealthScore({
    required double currentSpend,
    required double budget,
    required double recurringTotal,
    required Map<String, double> categorySpends,
    required int daysElapsed,
    required int totalDays,
  }) {
    int score = 0;
    final recommendations = <String>[];

    // 1. Budget Adherence (40 points)
    if (budget <= 0) {
      // If no budget set, award partial baseline
      score += 25;
      recommendations.add('Set a monthly budget to unlock active pacing and protection.');
    } else {
      final pacing = calculatePacing(
        spendSoFar: currentSpend,
        budget: budget,
        daysElapsed: daysElapsed,
        totalDays: totalDays,
      );

      if (pacing.status == PacingStatus.onTrack) {
        score += 40;
      } else if (pacing.status == PacingStatus.caution) {
        score += 26;
        recommendations.add(
          'Spending is pacing slightly ahead (+${((pacing.burnRate - 1.0) * 100).toStringAsFixed(0)}%). Cap discretionary expenses.',
        );
      } else {
        score += 10;
        recommendations.add(
          'Critical: Burn rate will overshoot budget by ${pacing.deltaFromBudget.abs().toStringAsFixed(0)}. Slow daily spend.',
        );
      }
    }

    // 2. Velocity & Stability (25 points)
    final validElapsed = math.max(1, daysElapsed);
    final avgDaily = currentSpend / validElapsed;
    if (avgDaily <= (budget > 0 ? (budget / math.max(1, totalDays)) : 1000)) {
      score += 25;
    } else {
      score += 14;
    }

    // 3. Category Concentration Risk (20 points)
    if (categorySpends.isNotEmpty && currentSpend > 0) {
      final maxCatSpend = categorySpends.values.reduce(math.max);
      final concentration = maxCatSpend / currentSpend;

      if (concentration <= 0.40) {
        score += 20;
      } else if (concentration <= 0.60) {
        score += 14;
        recommendations.add('One category accounts for over 40% of total spend. Consider diversification.');
      } else {
        score += 8;
        recommendations.add('High category concentration risk: over 60% in a single category.');
      }
    } else {
      score += 20;
    }

    // 4. Recurring Overhead Ratio (15 points)
    if (currentSpend > 0 && recurringTotal > 0) {
      final recurringRatio = recurringTotal / currentSpend;
      if (recurringRatio <= 0.30) {
        score += 15;
      } else if (recurringRatio <= 0.50) {
        score += 10;
        recommendations.add('Recurring subscriptions take 30–50% of your expenses. Audit unused services.');
      } else {
        score += 5;
        recommendations.add('High fixed overhead: recurring expenses exceed 50% of monthly spending.');
      }
    } else {
      score += 15;
    }

    score = math.max(0, math.min(100, score));

    HealthScoreTier tier;
    String summary;
    if (score >= 85) {
      tier = HealthScoreTier.excellent;
      summary = 'Exceptional financial discipline. Spending velocity is balanced and within target.';
    } else if (score >= 70) {
      tier = HealthScoreTier.good;
      summary = 'Solid spending habits. Minor adjustments to daily burn rate will optimize savings.';
    } else if (score >= 50) {
      tier = HealthScoreTier.fair;
      summary = 'Moderate budget pressure. Several categories are outpacing expected allocations.';
    } else {
      tier = HealthScoreTier.needsAttention;
      summary = 'High budget overshoot risk. Urgent rebalancing recommended to avoid deficit.';
    }

    if (recommendations.isEmpty) {
      recommendations.add('Maintain current spending rhythm. You are on track for a surplus.');
    }

    return HealthScoreReport(
      score: score,
      tier: tier,
      summary: summary,
      actionableRecommendations: recommendations,
    );
  }

  /// Solves group split balances into the absolute minimum number of settlement transfers
  /// using greedy bipartite matching between net creditors and net debtors.
  static List<SettlementTransfer> optimizeGroupSettlements(Map<String, double> netBalances) {
    // Separate into debtors (negative balance) and creditors (positive balance)
    final debtors = <String, double>{};
    final creditors = <String, double>{};

    netBalances.forEach((person, balance) {
      // Round to 2 decimal places to prevent floating point residue
      final rounded = (balance * 100).round() / 100;
      if (rounded < -0.01) {
        debtors[person] = -rounded; // store as positive amount owed
      } else if (rounded > 0.01) {
        creditors[person] = rounded;
      }
    });

    final transfers = <SettlementTransfer>[];

    // Convert to mutable lists sorted descending by magnitude
    final debtorList = debtors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final creditorList = creditors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    int dIdx = 0;
    int cIdx = 0;

    while (dIdx < debtorList.length && cIdx < creditorList.length) {
      final debtor = debtorList[dIdx];
      final creditor = creditorList[cIdx];

      final settleAmount = math.min(debtor.value, creditor.value);
      final roundedAmount = (settleAmount * 100).round() / 100;

      if (roundedAmount > 0.01) {
        transfers.add(
          SettlementTransfer(
            from: debtor.key,
            to: creditor.key,
            amount: roundedAmount,
          ),
        );
      }

      debtorList[dIdx] = MapEntry(debtor.key, debtor.value - settleAmount);
      creditorList[cIdx] = MapEntry(creditor.key, creditor.value - settleAmount);

      if (debtorList[dIdx].value < 0.01) {
        dIdx++;
      }
      if (creditorList[cIdx].value < 0.01) {
        cIdx++;
      }
    }

    return transfers;
  }
}
