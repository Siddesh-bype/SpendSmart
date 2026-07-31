import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/service_provider.dart';
import '../utils/constants.dart';
import '../utils/design.dart';

/// One-time account creation, shown on first launch after onboarding.
///
/// This is a local lock, not a cloud account: the credential never leaves the
/// device and there is no server to recover it from. The copy says so plainly,
/// because a forgotten password here means the data is unreachable.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    final recoveryCode = await ref
        .read(appSettingsProvider.notifier)
        .createAccount(_username.text, _password.text);

    // The boxes are already open and unencrypted at this point, because the
    // app ran without a lock. Re-open them with the new key so the existing
    // data is migrated rather than left in the clear.
    final masterKey = await ref
        .read(appSettingsProvider.notifier)
        .unlockWithPassword(_password.text);
    await ref
        .read(storageServiceProvider)
        .reopen(encryptionKey: masterKey == null || masterKey.isEmpty
            ? null
            : masterKey);

    if (!mounted) return;
    setState(() => _busy = false);
    await _showRecoveryCode(recoveryCode);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Shown once, and only once. The code is never stored in the clear, so if
  /// the user dismisses it without writing it down it is gone -- hence the
  /// explicit confirmation rather than a tap-anywhere dismiss.
  Future<void> _showRecoveryCode(String code) async {
    var acknowledged = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Save your recovery code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is the only way back in if you forget your password. '
                'Write it down and keep it somewhere safe — it will not be '
                'shown again.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: AppRadius.smAll,
                ),
                child: SelectableText(
                  code,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    HapticFeedback.selectionClick();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ),
              CheckboxListTile(
                value: acknowledged,
                onChanged: (v) =>
                    setDialogState(() => acknowledged = v ?? false),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('I have saved this code'),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Secure your expenses',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Pick a username and password. These stay on this device '
                      'and are never uploaded, so keep the password somewhere '
                      'safe — it cannot be reset.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _username,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Enter a username';
                        if (text.length < 3) {
                          return 'Use at least 3 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.key_outlined),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        final text = value ?? '';
                        if (text.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      validator: (value) => value == _password.text
                          ? null
                          : 'Passwords do not match',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          child: Text(
                            'Stored as a salted hash, never as text',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
