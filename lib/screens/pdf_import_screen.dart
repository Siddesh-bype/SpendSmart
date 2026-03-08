import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../services/pdf_import_service.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../utils/constants.dart';

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
    setState(() { _loading = true; _error = null; _parsed = []; _selected = {}; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) {
        setState(() => _loading = false);
        return;
      }
      final file = File(result.files.single.path!);
      _fileName = result.files.single.name;
      final parsed = await PdfImportService.parseBankStatement(file);
      setState(() {
        _parsed = parsed;
        _selected = parsed.map((e) => e.id).toSet();
        _loading = false;
        if (parsed.isEmpty) {
          _error = 'No transactions found in this PDF. Make sure it\'s a bank statement with debit transactions.';
        }
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'Failed to read PDF: $e'; });
    }
  }

  Future<void> _importSelected() async {
    setState(() => _importing = true);
    final toImport = _parsed.where((e) => _selected.contains(e.id)).toList();
    await ref.read(expenseProvider.notifier).importExpenses(toImport);
    setState(() { _importing = false; _parsed = []; _selected = {}; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Imported $toImport.length transactions successfully!'),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Bank Statement', style: TextStyle(fontWeight: FontWeight.bold)),
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
              child: Text(_selected.length == _parsed.length ? 'Deselect All' : 'Select All',
                style: const TextStyle(color: AppColors.primary)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Reading PDF...', style: TextStyle(color: Colors.grey)),
            ]))
          : _importing
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Importing transactions...', style: TextStyle(color: Colors.grey)),
                ]))
              : _parsed.isEmpty
                  ? _buildEmptyState()
                  : _buildTransactionList(),
      bottomNavigationBar: _parsed.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _selected.isEmpty ? null : _importSelected,
                  child: Text(
                    'Import ${_selected.length} Transaction${_selected.length != 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.picture_as_pdf, size: 52, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text('Import Bank Statement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Pick your bank\'s PDF statement to auto-import all debit transactions.\n\nSupported banks:\nHDFC • SBI • ICICI • Axis • Kotak • Yes Bank',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, height: 1.6),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text('Select PDF File', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _pickAndParse,
          ),
          const SizedBox(height: 16),
          const Text('PDF must be text-based (not scanned image)',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }

  Widget _buildTransactionList() {
    final byMonth = <String, List<Expense>>{};
    final currency = ref.read(appSettingsProvider).currency;
    for (final e in _parsed) {
      final key = DateFormat('MMMM yyyy').format(e.date);
      byMonth.putIfAbsent(key, () => []).add(e);
    }

    return Column(children: [
      // Summary banner
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.picture_as_pdf, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_fileName ?? 'Statement', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Found ${_parsed.length} debit transactions  •  ${_selected.length} selected',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
          TextButton(onPressed: _pickAndParse, child: const Text('Change')),
        ]),
      ),

      Expanded(
        child: ListView.builder(
          itemCount: byMonth.length,
          itemBuilder: (_, i) {
            final month = byMonth.keys.elementAt(i);
            final txns = byMonth[month]!;
            final monthTotal = txns.fold(0.0, (a, b) => a + b.amount);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(month, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  Text('$currency${NumberFormat('#,##0').format(monthTotal)}',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ]),
              ),
              ...txns.map((e) => CheckboxListTile(
                value: _selected.contains(e.id),
                onChanged: (v) => setState(() {
                  if (v == true) { _selected.add(e.id); }
                  else { _selected.remove(e.id); }
                }),
                activeColor: AppColors.primary,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Row(children: [
                  Container(width: 32, height: 32,
                    decoration: BoxDecoration(color: e.category.color.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(e.category.icon, size: 16, color: e.category.color)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                ]),
                subtitle: Padding(
                  padding: const EdgeInsets.only(left: 42),
                  child: Row(children: [
                    Text(DateFormat('dd MMM yyyy').format(e.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: e.category.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e.category.name, style: TextStyle(fontSize: 10, color: e.category.color)),
                    ),
                  ]),
                ),
                secondary: Text('$currency${NumberFormat('#,##0.##').format(e.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              )),
            ]);
          },
        ),
      ),
    ]);
  }
}
