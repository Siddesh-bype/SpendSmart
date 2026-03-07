import 'package:flutter/material.dart';
import '../models/category.dart';
import '../utils/constants.dart';

/// Shown when a transaction is auto-detected from a notification.
/// Lets the user categorize the expense before it is saved.
class TransactionDetectedDialog extends StatefulWidget {
  final String merchant;
  final double amount;
  final String rawMessage;
  final void Function(Category category) onSave;
  final VoidCallback onDismiss;

  const TransactionDetectedDialog({
    super.key,
    required this.merchant,
    required this.amount,
    required this.rawMessage,
    required this.onSave,
    required this.onDismiss,
  });

  @override
  State<TransactionDetectedDialog> createState() =>
      _TransactionDetectedDialogState();
}

class _TransactionDetectedDialogState
    extends State<TransactionDetectedDialog> with SingleTickerProviderStateMixin {
  Category _selected = Category.other;
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.elasticOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _scale,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Transaction Detected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Amount + merchant banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '₹${widget.amount % 1 == 0 ? widget.amount.toStringAsFixed(0) : widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(widget.merchant,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 14),
          Text('Where did you spend this?',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          // Category grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: Category.values.map((cat) {
              final isSelected = cat == _selected;
              return GestureDetector(
                onTap: () => setState(() => _selected = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cat.color.withValues(alpha: 0.2)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? cat.color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(cat.icon, color: cat.color, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? cat.color : theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
        ]),
        actions: [
          TextButton(
            onPressed: widget.onDismiss,
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => widget.onSave(_selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
