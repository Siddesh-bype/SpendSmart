import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/split_group.dart';
import '../models/group_expense.dart';
import '../providers/group_provider.dart';
import '../providers/group_expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../utils/constants.dart';
import '../utils/theme.dart';
import '../utils/design.dart';
import 'add_group_sheet.dart';
import 'group_detail_screen.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(splitGroupProvider);
    final allExpenses = ref.watch(groupExpenseProvider);
    final settings = ref.watch(appSettingsProvider);
    final currency = settings.currency;
    final scheme = SchemeTheme.of(context);

    // Summary totals across all groups
    double totalOwedToYou = 0;
    double totalYouOwe = 0;

    for (final group in groups) {
      final balances = _computeBalances(group, allExpenses);
      final netMe = _myNetBalance(group, balances);
      if (netMe > 0) totalOwedToYou += netMe;
      if (netMe < 0) totalYouOwe += netMe.abs();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bills', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Material(
              color: scheme.ctaFill,
              borderRadius: AppRadius.mdAll,
              child: InkWell(
                borderRadius: AppRadius.mdAll,
                onTap: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => const AddGroupSheet(),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 18, color: scheme.ctaText),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'New Group',
                        style: TextStyle(
                          color: scheme.ctaText,
                          fontSize: AppType.body,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        // Summary banner (solid surface + 1px border, compact)
        Container(
          margin: const EdgeInsets.all(AppSpacing.lg),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: scheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCol(
                context,
                'Owed to You',
                totalOwedToYou,
                scheme.success,
                currency,
              ),
              Container(width: 1, height: 36, color: scheme.border),
              _summaryCol(
                context,
                'You Owe',
                totalYouOwe,
                scheme.error,
                currency,
              ),
            ],
          ),
        ),

        if (groups.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_add_outlined, size: 72, color: scheme.muted),
                  const SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: TextStyle(
                      fontSize: AppType.headline,
                      fontWeight: FontWeight.bold,
                      color: scheme.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start splitting expenses',
                    style: TextStyle(color: scheme.muted, fontSize: AppType.label),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => const AddGroupSheet(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.ctaFill,
                        foregroundColor: scheme.ctaText,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      ),
                      child: const Text('Create group'),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                final balances = _computeBalances(group, allExpenses);
                final netYou = _myNetBalance(group, balances);
                final recentExpenses = allExpenses.where((e) => e.groupId == group.id).take(3).toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: scheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.mdAll,
                    side: BorderSide(color: scheme.border),
                  ),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group),
                        ),
                      );
                    },
                    borderRadius: AppRadius.mdAll,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            // Participant avatars
                            SizedBox(
                              width: 70,
                              height: 36,
                              child: Stack(
                                children: [
                                  for (int j = 0; j < group.participants.length.clamp(0, 3); j++)
                                    Positioned(
                                      left: j * 18.0,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Color(group.participants[j].avatarColorValue),
                                        child: Text(
                                          group.participants[j].name[0].toUpperCase(),
                                          style: TextStyle(
                                            color: Scheme.onAvatar(
                                              Color(group.participants[j].avatarColorValue),
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontSize: AppType.caption,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (group.participants.length > 3)
                                    Positioned(
                                      left: 3 * 18.0,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: scheme.muted,
                                        child: Text(
                                          '+${group.participants.length - 3}',
                                          style: TextStyle(
                                            color: scheme.surface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: AppType.micro,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppType.headline),
                                  ),
                                  Text(
                                    '${group.participants.length} members',
                                    style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  netYou >= 0
                                      ? '+$currency${NumberFormat('#,##0.##').format(netYou)}'
                                      : '-$currency${NumberFormat('#,##0.##').format(netYou.abs())}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: AppType.headline,
                                    color: netYou >= 0 ? scheme.success : scheme.error,
                                  ),
                                ),
                                Text(
                                  netYou >= 0 ? 'you are owed' : 'you owe',
                                  style: TextStyle(
                                    color: scheme.muted,
                                    fontSize: AppType.caption,
                                  ),
                                ),
                              ],
                            ),
                          ]),
                          if (recentExpenses.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Divider(height: 1, color: scheme.border),
                            const SizedBox(height: 8),
                            ...recentExpenses.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 14,
                                    color: scheme.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      e.description,
                                      style: TextStyle(fontSize: AppType.caption, color: scheme.muted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$currency${NumberFormat('#,##0.##').format(e.totalAmount)}',
                                    style: TextStyle(
                                      fontSize: AppType.caption,
                                      fontWeight: FontWeight.w600,
                                      color: e.isSettled ? scheme.muted : scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _summaryCol(BuildContext context, String label, double amount, Color valueColor, String currency) {
    final scheme = SchemeTheme.of(context);
    return Column(children: [
      Text(label, style: TextStyle(color: scheme.muted, fontSize: AppType.caption)),
      const SizedBox(height: 4),
      Text(
        '$currency${NumberFormat('#,##0').format(amount)}',
        style: TextStyle(color: valueColor, fontSize: AppType.headline, fontWeight: FontWeight.bold),
      ),
    ]);
  }

  Map<String, double> _computeBalances(SplitGroup group, List<GroupExpense> allExpenses) {
    final Map<String, double> totalPaid = {};
    final Map<String, double> totalOwed = {};

    for (final p in group.participants) {
      totalPaid[p.id] = 0;
      totalOwed[p.id] = 0;
    }

    final expenses = allExpenses.where((e) => e.groupId == group.id && !e.isSettled);
    for (final expense in expenses) {
      totalPaid[expense.paidBy] = (totalPaid[expense.paidBy] ?? 0) + expense.totalAmount;
      for (final share in expense.shares) {
        totalOwed[share.participantId] = (totalOwed[share.participantId] ?? 0) + share.amount;
      }
    }

    return {
      for (final p in group.participants)
        p.id: (totalPaid[p.id] ?? 0) - (totalOwed[p.id] ?? 0),
    };
  }

  double _myNetBalance(SplitGroup group, Map<String, double> balances) {
    // Whoever the group marks as "me" (default: first participant).
    final me = group.meParticipantId;
    if (me == null) return 0;
    return balances[me] ?? 0;
  }
}
