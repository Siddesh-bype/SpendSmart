import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/report_models.dart';
import '../providers/app_settings_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/expense_category_provider.dart';
import '../services/expense_category_resolver.dart';
import '../services/report_service.dart';
import '../utils/design.dart';
import '../utils/date_extension.dart';
import '../utils/theme.dart';
import '../widgets/money_text.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late ReportPreset _preset;
  late ReportDateRange _range;
  Category? _category;
  String? _customCategoryId;
  bool _includeUncategorized = false;
  ReportSortOrder _sortOrder = ReportSortOrder.newestFirst;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _preset = ReportPreset.currentFinancialPeriod;
    _range = ReportService.resolvePreset(
      _preset,
      now: DateTime.now(),
      startingDayOfMonth: settings.startingDayOfMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final expenses = ref.watch(expenseProvider);
    final catalog = ref.watch(expenseCategoryCatalogProvider);
    final configuration = ReportConfiguration(
      range: _range,
      category: _category,
      customCategoryId: _customCategoryId,
      includeUncategorized: _includeUncategorized,
      sortOrder: _sortOrder,
    );
    final report = ReportService.buildReport(
      expenses,
      configuration,
      catalog: catalog,
    );
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('DATE RANGE', style: _sectionStyle(scheme)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ReportPreset.values
                .map(
                  (preset) => ChoiceChip(
                    label: Text(preset.label),
                    selected: _preset == preset,
                    onSelected: (_) =>
                        _selectPreset(preset, settings.startingDayOfMonth),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          _rangeButton(
            context,
            icon: Icons.date_range_outlined,
            label: _rangeLabel(_range),
            onTap: _chooseCustomRange,
          ),
          const SizedBox(height: 24),
          Text('FILTERS', style: _sectionStyle(scheme)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedCategoryValue(catalog),
            decoration: const InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All categories'),
              ),
              ...Category.values.map(
                (category) => DropdownMenuItem(
                  value: 'builtIn:${category.index}',
                  child: Text(category.displayName),
                ),
              ),
              ...catalog.customCategories
                  .where((category) => !category.archived)
                  .map(
                    (category) => DropdownMenuItem(
                      value: 'custom:${category.id}',
                      child: Text(category.name),
                    ),
                  ),
            ],
            onChanged: (value) => setState(() {
              _category = null;
              _customCategoryId = null;
              if (value != null && value != 'all') {
                if (value.startsWith('custom:')) {
                  _customCategoryId = value.substring('custom:'.length);
                } else {
                  _category = Category
                      .values[int.parse(value.substring('builtIn:'.length))];
                }
              }
            }),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include uncategorized'),
            subtitle: const Text('Include expenses awaiting a category'),
            value: _includeUncategorized,
            onChanged: (value) => setState(() => _includeUncategorized = value),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<ReportSortOrder>(
            isExpanded: true,
            initialValue: _sortOrder,
            decoration: const InputDecoration(
              labelText: 'Sort order',
              prefixIcon: Icon(Icons.sort),
            ),
            items: ReportSortOrder.values
                .map(
                  (order) =>
                      DropdownMenuItem(value: order, child: Text(order.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _sortOrder = value);
            },
          ),
          const SizedBox(height: 24),
          _previewCard(report, settings.currency, scheme),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share PDF'),
                  onPressed: report.expenses.isEmpty || _isExporting
                      ? null
                      : () => _sharePdf(report, settings.currency),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart_outlined),
                  label: const Text('Share CSV'),
                  onPressed: report.expenses.isEmpty || _isExporting
                      ? null
                      : () => _shareCsv(report),
                ),
              ),
            ],
          ),
          if (report.expenses.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'No expenses match these settings. Adjust the range or filters to export a report.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _sectionStyle(SchemeTheme scheme) => TextStyle(
    color: scheme.muted,
    fontSize: AppType.label,
    fontWeight: FontWeight.bold,
    letterSpacing: 1.2,
  );

  Widget _rangeButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      alignment: Alignment.centerLeft,
    ),
  );

  Widget _previewCard(ReportData report, String currency, SchemeTheme scheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('REPORT PREVIEW', style: _sectionStyle(scheme)),
          const SizedBox(height: 12),
          Text(
            _rangeLabel(report.configuration.range),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _metric(
                  'Transactions',
                  '${report.expenses.length}',
                  scheme,
                ),
              ),
              Expanded(
                child: _metric(
                  'Total',
                  formatMoney(report.total, currency: currency, decimals: true),
                  scheme,
                ),
              ),
              Expanded(
                child: _metric(
                  'Days',
                  '${report.configuration.range.dayCount}',
                  scheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, SchemeTheme scheme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ],
  );

  void _selectPreset(ReportPreset preset, int startingDay) {
    if (preset == ReportPreset.custom) {
      _chooseCustomRange();
      return;
    }
    setState(() {
      _preset = preset;
      _range = ReportService.resolvePreset(
        preset,
        now: DateTime.now(),
        startingDayOfMonth: startingDay,
      );
    });
  }

  Future<void> _chooseCustomRange() async {
    final start = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _range.start,
      helpText: 'Select start date',
    );
    if (start == null || !mounted) return;
    final initialEnd = _range.endInclusive.isBefore(start)
        ? start
        : _range.endInclusive;
    final end = await showDatePicker(
      context: context,
      firstDate: start,
      lastDate: DateTime(2100),
      initialDate: initialEnd,
      helpText: 'Select end date',
    );
    if (end == null || !mounted) return;
    setState(() {
      _preset = ReportPreset.custom;
      _range = ReportDateRange(start: start, endInclusive: end);
    });
  }

  Future<void> _sharePdf(ReportData report, String currency) async {
    await _share(
      create: () => ReportService.exportPdf(report, currency: currency),
      subject: 'SpendSmart PDF Expense Report',
      message:
          'SpendSmart expense report for ${_rangeLabel(report.configuration.range)}',
    );
  }

  Future<void> _shareCsv(ReportData report) async {
    await _share(
      create: () => ReportService.exportCsv(report),
      subject: 'SpendSmart CSV Expense Report',
      message:
          'SpendSmart expense report for ${_rangeLabel(report.configuration.range)}',
    );
  }

  Future<void> _share({
    required Future<String> Function() create,
    required String subject,
    required String message,
  }) async {
    setState(() => _isExporting = true);
    try {
      HapticFeedback.lightImpact();
      final path = await create();
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      final shareOrigin = renderObject is RenderBox
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      await Share.shareXFiles(
        [XFile(path)],
        subject: subject,
        text: message,
        sharePositionOrigin: shareOrigin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create the report. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _rangeLabel(ReportDateRange range) =>
      '${displayDateFormat.format(range.start)} – '
      '${displayDateFormat.format(range.endInclusive)}';

  String _selectedCategoryValue(ExpenseCategoryCatalog catalog) {
    if (_customCategoryId != null &&
        catalog.customById(_customCategoryId!)?.archived == false) {
      return 'custom:$_customCategoryId';
    }
    return _category == null ? 'all' : 'builtIn:${_category!.index}';
  }
}
