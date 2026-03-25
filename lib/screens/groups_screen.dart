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

    // Summary totals across all groups
    double totalOwedToYou = 0;
    double totalYouOwe = 0;

    for (final group in groups) {
      final balances = _computeBalances(group, allExpenses);
      for (final entry in balances.entries) {
        if (entry.value > 0) totalOwedToYou += entry.value;
        if (entry.value < 0) totalYouOwe += entry.value.abs();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split Bills', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Summary banner
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryCol(
                'Owed to You',
                totalOwedToYou,
                Colors.green.shade200,
                currency,
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              _summaryCol(
                'You Owe',
                totalYouOwe,
                Colors.red.shade200,
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
                  Icon(Icons.group_add_outlined, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'No groups yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start splitting expenses',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
                final netYou = _myNetBalance(balances);
                final recentExpenses = allExpenses.where((e) => e.groupId == group.id).take(3).toList();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    borderRadius: BorderRadius.circular(14),
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
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (group.participants.length > 3)
                                    Positioned(
                                      left: 3 * 18.0,
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.grey.shade400,
                                        child: Text(
                                          '+${group.participants.length - 3}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    '${group.participants.length} members',
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
                                    fontSize: 16,
                                    color: netYou >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                                Text(
                                  netYou >= 0 ? 'you are owed' : 'you owe',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ]),
                          if (recentExpenses.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            ...recentExpenses.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_outlined,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      e.description,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$currency${NumberFormat('#,##0.##').format(e.totalAmount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: e.isSettled ? Colors.grey : AppColors.primary,
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
      floatingActionButton: FloatingActionButton.extended(
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
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _summaryCol(String label, double amount, Color valueColor, String currency) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      const SizedBox(height: 4),
      Text(
        '$currency${NumberFormat('#,##0').format(amount)}',
        style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold),
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

  double _myNetBalance(Map<String, double> balances) {
    // For simplicity, treat the first participant as "me"
    if (balances.isEmpty) return 0;
    return balances.values.first;
  }
}
