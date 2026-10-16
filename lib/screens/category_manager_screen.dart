import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/custom_category.dart';
import '../providers/custom_category_provider.dart';
import '../utils/design.dart';
import '../utils/theme.dart';

class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
  });

  final String name;
  final int iconCodePoint;
  final int colorValue;
}

class CategoryManagerScreen extends ConsumerWidget {
  const CategoryManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(customCategoryProvider);
    final scheme = SchemeTheme.of(context);
    final active = categories.where((value) => !value.archived).toList();
    final archived = categories.where((value) => value.archived).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom + 72,
        ),
        children: [
          Text(
            'Create categories that fit your life. Existing expenses keep their stable category id when you rename or combine categories.',
            style: TextStyle(color: scheme.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (active.isEmpty)
            _empty(context, 'No custom categories yet.')
          else
            for (final category in active) _categoryTile(context, ref, category),
          if (archived.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('ARCHIVED', style: TextStyle(color: scheme.muted, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            for (final category in archived)
              ListTile(
                leading: Icon(category.icon, color: scheme.muted),
                title: Text(category.name),
                subtitle: Text(
                  category.mergedIntoId == null
                      ? 'Archived'
                      : 'Combined into another category',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text(text)),
      );

  Widget _categoryTile(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) {
    final scheme = SchemeTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.color.withValues(alpha: 0.16),
          child: Icon(category.icon, color: category.color),
        ),
        title: Text(category.name),
        subtitle: const Text('Custom category'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'rename') _showRename(context, ref, category);
            if (value == 'archive') _confirmArchive(context, ref, category);
            if (value == 'merge') _showMerge(context, ref, category);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'merge', child: Text('Combine into…')),
            PopupMenuItem(value: 'archive', child: Text('Archive')),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final draft = await _categoryDialog(context);
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(customCategoryProvider.notifier).add(
            name: draft.name,
            iconCodePoint: draft.iconCodePoint,
            colorValue: draft.colorValue,
          );
    } catch (error) {
      if (context.mounted) _error(context, error.toString());
    }
  }

  Future<void> _showRename(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) async {
    final value = await _textDialog(
      context,
      'Rename category',
      'Category name',
      initialValue: category.name,
    );
    if (value == null || !context.mounted) return;
    try {
      await ref.read(customCategoryProvider.notifier).rename(category, value);
    } catch (error) {
      if (context.mounted) _error(context, error.toString());
    }
  }

  Future<void> _showMerge(
    BuildContext context,
    WidgetRef ref,
    CustomCategory source,
  ) async {
    final choices = ref
        .read(customCategoryProvider)
        .where((value) => !value.archived && value.id != source.id)
        .toList();
    if (choices.isEmpty) {
      _error(context, 'Add another active custom category first.');
      return;
    }
    final destination = await showDialog<CustomCategory>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('Combine ${source.name} into…'),
        children: [
          for (final choice in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, choice),
              child: Text(choice.name),
            ),
        ],
      ),
    );
    if (destination == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Combine categories?'),
        content: Text(
          'New selections will use ${destination.name}. Existing ${source.name} records remain readable and the source category will be archived.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Combine')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(customCategoryProvider.notifier).merge(source, destination);
    } catch (error) {
      if (context.mounted) _error(context, 'Could not combine categories: $error');
    }
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    CustomCategory category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive category?'),
        content: Text('Archive ${category.name}? Existing records remain intact.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(customCategoryProvider.notifier).archive(category);
    }
  }

  Future<String?> _textDialog(
    BuildContext context,
    String title,
    String label, {
    String? initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<_CategoryDraft?> _categoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    var iconCodePoint = Icons.category.codePoint;
    var colorValue = 0xFF9AB8EE;
    const iconChoices = customCategoryIcons;
    const colorChoices = [
      0xFF9AB8EE,
      0xFF7ED6A5,
      0xFFFFB86B,
      0xFFE98BAA,
      0xFFC3A6FF,
      0xFF6ED0D8,
    ];
    final result = await showDialog<_CategoryDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Category name'),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Icon'),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    for (final icon in iconChoices)
                      IconButton(
                        tooltip: 'Choose icon',
                        style: IconButton.styleFrom(
                          backgroundColor: icon.codePoint == iconCodePoint
                              ? SchemeTheme.of(context).primary.withValues(alpha: 0.16)
                              : null,
                        ),
                        onPressed: () => setDialogState(
                          () => iconCodePoint = icon.codePoint,
                        ),
                        icon: Icon(icon),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text('Color'),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final color in colorChoices)
                      InkWell(
                        onTap: () => setDialogState(() => colorValue = color),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(color),
                            shape: BoxShape.circle,
                            border: color == colorValue
                                ? Border.all(
                                    color: SchemeTheme.of(context).ink,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _CategoryDraft(
                  name: controller.text,
                  iconCodePoint: iconCodePoint,
                  colorValue: colorValue,
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _error(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
