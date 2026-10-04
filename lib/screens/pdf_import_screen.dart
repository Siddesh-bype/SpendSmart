import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/pdf_import_service.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/service_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../utils/theme.dart';
import '../utils/design.dart';
import '../widgets/empty_state.dart';

class PdfImportScreen extends ConsumerStatefulWidget {
  const PdfImportScreen({super.key});

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  bool _loading = false;
  bool _importing = false;
  List<Expense> _parsed = [];
  Set<String> _selected = {};
  String? _fileName;
  String? _error;

  Future<void> _pickAndParse() async {
    // Captured before the picker await — ref is unsafe once this State is gone.
    final memoryLookup = ref.read(storageServiceProvider).lookupMerchantCategory;
    setState(() {
      _loading = true;
      _error = null;
      _parsed = [];
      _selected = {};
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final picked = result.files.single;
      final path = picked.path;
      if (path == null || path.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Could not read the selected PDF.';
        });
        return;
      }
      if (picked.size > PdfImportService.maxPdfBytes) {
        setState(() {
          _loading = false;
          _error = 'PDF is too large. Choose a file under 10 MB.';
        });
        return;
      }

      final file = File(path);
      _fileName = picked.name;
      final parsed = await PdfImportService.parseBankStatement(
        file,
        memoryLookup: memoryLookup,
      );
      if (!mounted) return;
      setState(() {
        _parsed = parsed;
        _selected = parsed.map((e) => e.id).toSet();
        _loading = false;
        if (parsed.isEmpty) {
          _error =
              'No transactions found in this PDF. Make sure it\'s a bank statement with debit transactions.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to read this PDF. Try a text-based bank statement.';
      });
    }
  }

  Future<void> _importSelected() async {
    setState(() => _importing = true);
    final toImport = _parsed.where((e) => _selected.contains(e.id)).toList();
    int inserted;
    try {
      inserted = await ref
          .read(expenseProvider.notifier)
          .importExpenses(toImport);
    } catch (_) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not import the selected transactions.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final duplicates = toImport.length - inserted;
    setState(() {
      _importing = false;
      _parsed = [];
      _selected = {};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported $inserted transaction${inserted == 1 ? '' : 's'}. '
          '$duplicates duplicate${duplicates == 1 ? '' : 's'} skipped.',
        ),
        backgroundColor: SchemeTheme.of(context).success,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Import Bank Statement',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_parsed.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                if (_selected.length == _parsed.length) {
                  _selected.clear();
                } else {
                  _selected = _parsed.map((e) => e.id).toSet();
                }
              }),
              child: Text(
                _selected.length == _parsed.length
                    ? 'Deselect All'
                    : 'Select All',
                style: TextStyle(color: scheme.primary),
              ),
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 16),
                  Text('Reading PDF...', style: TextStyle(color: scheme.muted)),
                ],
              ),
            )
          : _importing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Importing transactions...',
                    style: TextStyle(color: scheme.muted),
                  ),
                ],
              ),
            )
          : _parsed.isEmpty
          ? _buildEmptyState(scheme)
          : _buildTransactionList(scheme),
      bottomNavigationBar: _parsed.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                    disabledBackgroundColor: scheme.border,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  onPressed: _selected.isEmpty ? null : _importSelected,
                  child: Text(
                    'Import ${_selected.length} Transaction${_selected.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: AppType.headline,
                      fontWeight: FontWeight.bold,
                      color: scheme.ctaText,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(SchemeTheme scheme) {
    return Center(
      child: SingleChildScrollView(
        child: EmptyState(
          icon: Icons.upload_file_rounded,
          iconColor: scheme.primary.withValues(alpha: 0.5),
          title: 'Import Bank Statement',
          subtitle:
              'Pick your bank\'s PDF statement to auto-import debit transactions.\n\nSupported banks: HDFC, SBI, ICICI, Axis, Kotak, Yes Bank',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: AppRadius.mdAll,
                    border: Border.all(color: scheme.error),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: scheme.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.error, fontSize: AppType.label),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.ctaFill,
                  foregroundColor: scheme.ctaText,
                  minimumSize: const Size(200, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
                ),
                icon: Icon(Icons.upload_file, color: scheme.ctaText),
                label: Text(
                  'Select PDF File',
                  style: TextStyle(
                    fontSize: AppType.headline,
                    color: scheme.ctaText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _pickAndParse,
              ),
              const SizedBox(height: 16),
              Text(
                'PDF must be text-based (not scanned image)',
                style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList(SchemeTheme scheme) {
    final byMonth = <String, List<Expense>>{};
    final currency = ref.read(appSettingsProvider).currency;
    for (final e in _parsed) {
      final key = DateFormat('MMMM yyyy').format(e.date);
      byMonth.putIfAbsent(key, () => []).add(e);
    }

    return Column(
      children: [
        // Summary banner (solid surface + 1px border)
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: scheme.border),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? 'Statement',
                      style: TextStyle(fontWeight: FontWeight.bold, color: scheme.ink),
                    ),
                    Text(
                      'Found ${_parsed.length} debit transactions - ${_selected.length} selected',
                      style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _pickAndParse,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  minimumSize: const Size(64, 44),
                ),
                child: const Text('Change'),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            itemCount: byMonth.length,
            itemBuilder: (_, i) {
              final month = byMonth.keys.elementAt(i);
              final txns = byMonth[month]!;
              final monthTotal = txns.fold(0.0, (a, b) => a + b.amount);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          month,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.muted,
                            fontSize: AppType.label,
                          ),
                        ),
                        Text(
                          '$currency${NumberFormat('#,##0').format(monthTotal)}',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...txns.map(
                    (e) => CheckboxListTile(
                      value: _selected.contains(e.id),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(e.id);
                        } else {
                          _selected.remove(e.id);
                        }
                      }),
                      activeColor: scheme.primary,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: e.category.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              e.category.icon,
                              size: 16,
                              color: e.category.color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: AppType.body,
                                color: scheme.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 42),
                        child: Row(
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(e.date),
                              style: TextStyle(
                                fontSize: AppType.caption,
                                color: scheme.muted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: e.category.color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                e.category.displayName,
                                style: TextStyle(
                                  fontSize: AppType.micro,
                                  color: e.category.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      secondary: Text(
                        '$currency${NumberFormat('#,##0.##').format(e.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
