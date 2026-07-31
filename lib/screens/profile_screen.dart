import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/service_provider.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import 'login_screen.dart';

/// Account details for the local app lock.
///
/// There is no server here: the username and password guard this device only.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var wrongCurrent = false;

    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    errorText: wrongCurrent ? 'Incorrect password' : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) =>
                      (v ?? '').length < 6 ? 'Use at least 6 characters' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (v) =>
                      v == next.text ? null : 'Passwords do not match',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final ok = await ref
                    .read(appSettingsProvider.notifier)
                    .verifyPassword(current.text);
                if (!ok) {
                  setDialogState(() => wrongCurrent = true);
                  return;
                }
                await ref
                    .read(appSettingsProvider.notifier)
                    .changePassword(current.text, next.text);
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );

    current.dispose();
    next.dispose();
    confirm.dispose();

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    }
  }

  Future<void> _signOut() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final initial = settings.username.isEmpty
        ? '?'
        : settings.username.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  settings.username.isEmpty ? 'No account' : settings.username,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Signed in on this device',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your password is stored as a salted hash on this device '
                      'and never leaves it. Expenses are never uploaded.',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Lock now'),
            subtitle: const Text('Require the password again'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _signOut,
          ),
          ListTile(
            leading: const Icon(Icons.lock_open_outlined),
            title: const Text('Remove app lock'),
            subtitle: const Text('Stop asking for a password on open'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _removeLock,
          ),
        ],
      ),
    );
  }

  /// Turning the lock off also decrypts, since the key is derived from the
  /// password being removed. Requires the password: otherwise anyone holding
  /// an unlocked phone could strip the lock outright.
  Future<void> _removeLock() async {
    final password = TextEditingController();
    var wrong = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Remove app lock?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your expenses will no longer be encrypted, and anyone with '
                'this phone will be able to open the app.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: password,
                obscureText: true,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: wrong ? 'Incorrect password' : null,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await ref
                    .read(appSettingsProvider.notifier)
                    .verifyPassword(password.text);
                if (!ok) {
                  setDialogState(() => wrong = true);
                  return;
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove'),
            ),
          ],
        ),
      ),
    );

    password.dispose();
    if (confirmed != true || !mounted) return;

    // Decrypt first, then forget the credential. The reverse order would leave
    // the boxes encrypted under a key nothing can derive any more.
    await ref.read(storageServiceProvider).decryptToPlaintext();
    await ref.read(appSettingsProvider.notifier).removeAccount();

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App lock removed')),
    );
  }
}
