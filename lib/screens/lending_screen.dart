import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:uuid/uuid.dart';
import '../models/lending.dart';
import '../providers/app_settings_provider.dart';
import '../providers/lending_provider.dart';
import '../services/lending_pdf_service.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';

enum _LendingFilter { active, settled, all }

class LendingScreen extends ConsumerStatefulWidget {
  const LendingScreen({super.key});

  @override
  ConsumerState<LendingScreen> createState() => _LendingScreenState();
}

class _LendingScreenState extends ConsumerState<LendingScreen> {
  final _searchController = TextEditingController();
  final _settlingIds = <String>{};
  bool _exporting = false;
  _LendingFilter _filter = _LendingFilter.active;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportPDF(List<Lending> lendings, String currency) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating PDF…'),
        duration: Duration(seconds: 3),
      ),
    );
    try {
      final path = await LendingPdfService.exportToPDF(
        lendings,
        currency: currency,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF exported successfully'),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: SchemeTheme.of(context).primary,
            onPressed: () => OpenFilex.open(path),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lendings = ref.watch(lendingProvider);
    final currency = ref.watch(appSettingsProvider).currency;
    final visible = lendings.where(_matchesCurrentView).toList();
    final active = lendings.where((entry) => !entry.isSettled).toList();
    final byFriend = _groupByFriend(visible);
    final activeByFriend = _groupByFriend(active);
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lend & Borrow'),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'Export PDF',
              onPressed: lendings.isEmpty
                  ? null
                  : () => _exportPDF(lendings, currency),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Record lending',
            onPressed: () => _showLendingSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search friends or notes',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_LendingFilter>(
                segments: const [
                  ButtonSegment(
                    value: _LendingFilter.active,
                    label: Text('Active'),
                  ),
                  ButtonSegment(
                    value: _LendingFilter.settled,
                    label: Text('Settled'),
                  ),
                  ButtonSegment(
                    value: _LendingFilter.all,
                    label: Text('All'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) =>
                    setState(() => _filter = selection.first),
              ),
            ),
          ),
          _summary(
            activeByFriend,
            currency,
            scheme,
          ),
          Expanded(
            child: visible.isEmpty
                ? _emptyState(
                    hasRecords: lendings.isNotEmpty,
                    hasSearch: _searchController.text.trim().isNotEmpty,
                    scheme: scheme,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    children: byFriend.entries
                        .map(
                          (entry) => _friendCard(
                            entry.key,
                            entry.value,
                            currency,
                            scheme,
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  bool _matchesCurrentView(Lending lending) {
    final statusMatches = switch (_filter) {
      _LendingFilter.active => !lending.isSettled,
      _LendingFilter.settled => lending.isSettled,
      _LendingFilter.all => true,
    };
    if (!statusMatches) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    return lending.friendName.toLowerCase().contains(query) ||
        lending.note.toLowerCase().contains(query);
  }

  Map<String, List<Lending>> _groupByFriend(Iterable<Lending> entries) {
    final grouped = <String, List<Lending>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.friendName, () => []).add(entry);
    }
    return grouped;
  }

  Widget _summary(
    Map<String, List<Lending>> activeByFriend,
    String currency,
    SchemeTheme scheme,
  ) {
    var owedToYou = 0.0;
    var youOwe = 0.0;
    for (final entries in activeByFriend.values) {
      final net = entries.fold<double>(
        0,
        (total, entry) => total + (entry.isIGave ? entry.amount : -entry.amount),
      );
      if (net >= 0) {
        owedToYou += net;
      } else {
        youOwe += net.abs();
      }
    }
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCol(
              'Owed to you',
              owedToYou,
              scheme.success,
              currency,
              scheme,
            ),
          ),
          Container(width: 1, height: 40, color: scheme.border),
          Expanded(
            child: _summaryCol(
              'You owe',
              youOwe,
              scheme.error,
              currency,
              scheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCol(
    String label,
    double amount,
    Color valueColor,
    String currency,
    SchemeTheme scheme,
  ) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$currency${NumberFormat('#,##0').format(amount)}',
          style: TextStyle(
            color: valueColor,
            fontSize: AppType.title,
            fontWeight: FontWeight.bold,
            fontFeatures: AppType.tabular,
          ),
        ),
      ],
    );
  }

  Widget _friendCard(
    String friendName,
    List<Lending> entries,
    String currency,
    SchemeTheme scheme,
  ) {
    final activeEntries = entries.where((entry) => !entry.isSettled).toList();
    final net = activeEntries.fold<double>(
      0,
      (total, entry) => total + (entry.isIGave ? entry.amount : -entry.amount),
    );
    final isOwed = net >= 0;
    final balanceLabel = activeEntries.isEmpty
        ? 'Settled'
        : isOwed
            ? 'Owed to you ${_money(net, currency)}'
            : 'You owe ${_money(net.abs(), currency)}';
    final balanceColor = activeEntries.isEmpty
        ? scheme.muted
        : isOwed
            ? scheme.success
            : scheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.xs),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: balanceColor.withValues(alpha: 0.15),
          child: Text(
            friendName.isEmpty ? '?' : friendName[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: balanceColor),
          ),
        ),
        title: Text(
          friendName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              balanceLabel,
              style: TextStyle(
                color: balanceColor,
                fontWeight: FontWeight.w600,
                fontSize: AppType.label,
              ),
            ),
            if (activeEntries.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _settleFriend(friendName, activeEntries),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Settle all'),
                ),
              ),
          ],
        ),
        children: entries
            .map((entry) => _lendingTile(entry, currency, scheme))
            .toList(),
      ),
    );
  }

  Widget _lendingTile(Lending lending, String currency, SchemeTheme scheme) {
    final entryColor = lending.isIGave ? scheme.success : scheme.error;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Icon(
        lending.isIGave
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded,
        color: entryColor,
      ),
      title: Text(
        lending.isIGave
            ? 'You gave ${_money(lending.amount, currency)}'
            : 'You owe ${_money(lending.amount, currency)}',
        style: TextStyle(
          color: entryColor,
          fontWeight: FontWeight.w600,
          fontSize: AppType.label,
        ),
      ),
      subtitle: Text(
        '${DateFormat('d MMM y').format(lending.date)}'
        '${lending.note.isNotEmpty ? ' · ${lending.note}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: AppType.caption, color: scheme.muted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!lending.isSettled)
            TextButton(
              onPressed: _settlingIds.contains(lending.id)
                  ? null
                  : () => _settle(lending),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
              child: Text(
                _settlingIds.contains(lending.id) ? 'Saving…' : 'Settle',
                style: const TextStyle(fontSize: AppType.caption),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'Settled',
                style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Entry actions',
            onSelected: (action) {
              if (action == 'edit') _showLendingSheet(context, lending);
              if (action == 'delete') _confirmDelete(lending);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  String _money(double amount, String currency) =>
      '$currency${NumberFormat('#,##0').format(amount)}';

  Widget _emptyState({
    required bool hasRecords,
    required bool hasSearch,
    required SchemeTheme scheme,
  }) {
    final title = hasSearch
        ? 'No matching lending entries'
        : hasRecords
            ? _filter == _LendingFilter.settled
                ? 'No settled entries'
                : 'No active lendings'
            : 'No lending entries yet';
    final message = hasSearch
        ? 'Try a different friend name or note.'
        : hasRecords
            ? 'Switch filters or record a new lending entry.'
            : 'Track money you gave or owe so every balance stays clear.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.people_alt_outlined,
              size: 64,
              color: scheme.muted.withValues(alpha: 0.55),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppType.headline,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.muted, fontSize: AppType.label),
            ),
            if (!hasRecords && !hasSearch) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () => _showLendingSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Record lending'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _settle(Lending lending) async {
    if (_settlingIds.contains(lending.id)) return;
    setState(() => _settlingIds.add(lending.id));
    HapticFeedback.lightImpact();
    try {
      await ref.read(lendingProvider.notifier).settle(lending.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as settled')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not settle this entry. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _settlingIds.remove(lending.id));
    }
  }

  Future<void> _settleFriend(
    String friendName,
    List<Lending> activeEntries,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Settle all with $friendName?'),
        content: Text(
          'This will mark ${activeEntries.length} active '
          '${activeEntries.length == 1 ? 'entry' : 'entries'} as settled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Settle all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final count = await ref
          .read(lendingProvider.notifier)
          .settleAllForFriend(friendName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count entries marked as settled')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not settle these entries. Try again.')),
      );
    }
  }

  Future<void> _confirmDelete(Lending lending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete lending entry?'),
        content: Text(
          'Remove the ${_money(lending.amount, ref.read(appSettingsProvider).currency)} '
          'entry with ${lending.friendName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await ref.read(lendingProvider.notifier).deleteLending(
            lending.id,
          );
      if (deleted == null || !mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearMaterialBanners();
      messenger.showMaterialBanner(
        MaterialBanner(
          content: Text('${lending.friendName} entry deleted'),
          leading: Icon(Icons.delete_outline, color: SchemeTheme.of(context).error),
          forceActionsBelow: true,
          actions: [
            TextButton(
              onPressed: () async {
                messenger.hideCurrentMaterialBanner();
                try {
                  await ref.read(lendingProvider.notifier).restoreLending(deleted);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Lending entry restored')),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Could not restore entry.')),
                    );
                  }
                }
              },
              child: const Text('UNDO'),
            ),
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text('DISMISS'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this entry. Try again.')),
      );
    }
  }

  void _showLendingSheet(BuildContext context, [Lending? lending]) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LendingSheet(ref: ref, initial: lending),
    );
  }
}

class _LendingSheet extends StatefulWidget {
  const _LendingSheet({required this.ref, this.initial});

  final WidgetRef ref;
  final Lending? initial;

  @override
  State<_LendingSheet> createState() => _LendingSheetState();
}

class _LendingSheetState extends State<_LendingSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late bool _iGave;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.friendName ?? '');
    _amountController = TextEditingController(
      text: initial == null ? '' : initial.amount.toString(),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _iGave = initial?.isIGave ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = parsePositiveAmount(_amountController.text);
    if (name.isEmpty || amount == null) {
      setState(() => _error = 'Please enter a valid name and amount.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final initial = widget.initial;
    final lending = Lending(
      id: initial?.id ?? const Uuid().v4(),
      friendName: name,
      amount: amount,
      isIGave: _iGave,
      date: initial?.date ?? DateTime.now(),
      note: _noteController.text.trim(),
      isSettled: initial?.isSettled ?? false,
    );
    try {
      final notifier = widget.ref.read(lendingProvider.notifier);
      if (_editing) {
        await notifier.updateLending(lending);
      } else {
        await notifier.addLending(lending);
      }
      if (!mounted) return;
      Navigator.pop(context);
      HapticFeedback.mediumImpact();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Could not update this entry. Try again.'
                : 'Could not save this entry. Try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);
    final currency = widget.ref.read(appSettingsProvider).currency;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              _editing ? 'Edit Lending' : 'Record Lending',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('I gave')),
                ButtonSegment(value: false, label: Text('I owe')),
              ],
              selected: {_iGave},
              onSelectionChanged: (selection) =>
                  setState(() => _iGave = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Friend's name",
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount ($currency)',
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _noteController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: scheme.error, fontSize: AppType.label),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : _editing ? 'Update' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
