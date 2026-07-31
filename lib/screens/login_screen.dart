import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/service_provider.dart';
import '../utils/design.dart';
import 'main_scaffold.dart';

/// Unlock screen shown on launch once an account exists.
///
/// Everything here is local. There is no network call, so the lock works in
/// airplane mode exactly as it does online.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _usingRecoveryCode = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final notifier = ref.read(appSettingsProvider.notifier);
    final masterKey = _usingRecoveryCode
        ? await notifier.unlockWithRecoveryCode(_password.text)
        : await notifier.unlockWithPassword(_password.text);

    if (!mounted) return;
    if (masterKey == null) {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = _usingRecoveryCode
            ? 'That recovery code did not work'
            : 'Incorrect password';
        _password.clear();
      });
      return;
    }

    // An empty key means a pre-encryption install: open the boxes in the clear.
    await ref
        .read(storageServiceProvider)
        .init(encryptionKey: masterKey.isEmpty ? null : masterKey);

    if (!mounted) return;

    // An existing account that just gained encryption gets a recovery code.
    final newCode = notifier.pendingRecoveryCode;
    if (newCode != null) {
      notifier.pendingRecoveryCode = null;
      await _showRecoveryCode(newCode);
      if (!mounted) return;
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  /// Shown once when an existing account is upgraded to encrypted storage.
  Future<void> _showRecoveryCode(String code) async {
    var acknowledged = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Your data is now encrypted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save this recovery code. It is the only way back in if you '
                'forget your password, and it will not be shown again.',
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
    final settings = ref.watch(appSettingsProvider);
    final username = settings.username;
    final hasRecovery = settings.wrappedKeyByRecovery.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: AppRadius.lgAll,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 72,
                      height: 72,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Welcome back${username.isEmpty ? '' : ', $username'}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _password,
                    obscureText: _obscure && !_usingRecoveryCode,
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: _usingRecoveryCode
                          ? 'Recovery code'
                          : 'Password',
                      hintText: _usingRecoveryCode ? 'XXXX-XXXX-XXXX-XXXX' : null,
                      errorText: _error,
                      prefixIcon: Icon(
                        _usingRecoveryCode
                            ? Icons.confirmation_number_outlined
                            : Icons.key_outlined,
                      ),
                      suffixIcon: _usingRecoveryCode
                          ? null
                          : IconButton(
                              tooltip: _obscure
                                  ? 'Show password'
                                  : 'Hide password',
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                    ),
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
                        : const Text('Unlock'),
                  ),
                  if (hasRecovery) ...[
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _usingRecoveryCode = !_usingRecoveryCode;
                              _password.clear();
                              _error = null;
                            }),
                      child: Text(
                        _usingRecoveryCode
                            ? 'Use my password instead'
                            : 'Forgot password?',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
