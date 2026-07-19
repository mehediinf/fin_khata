import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.forcedReauth = false});

  /// True when `HomeGate` is showing this screen because a previously
  /// logged-in session's refresh token died — there is nothing to pop back
  /// to in that case. False when opened as a normal pushed screen from
  /// Settings' "Cloud sync" entry.
  final bool forcedReauth;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isRegisterMode = false;
  bool _busy = false;
  String? _errorText;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Email and password are required.');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final notifier = ref.read(authControllerProvider.notifier);
      if (_isRegisterMode) {
        await notifier.register(email, password);
      } else {
        await notifier.login(email, password);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorText = error.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!widget.forcedReauth && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final topColor = isDark ? const Color(0xFF071A14) : const Color(0xFFE7F5EF);
    final bottomColor = isDark
        ? const Color(0xFF0B6B53)
        : const Color(0xFFBCE6D7);

    return PopScope(
      canPop: !widget.forcedReauth,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [topColor, bottomColor],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: .28),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.cloud_sync_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.forcedReauth
                          ? 'Sign in again to continue syncing'
                          : (_isRegisterMode
                                ? 'Create a cloud sync account'
                                : 'Log in to cloud sync'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sync your workspace across devices. Your data is '
                      'stored on our own server.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .68),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: _isRegisterMode
                              ? 'Password (min 8 characters)'
                              : 'Password',
                          errorText: _errorText,
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 280,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(_isRegisterMode ? 'Create account' : 'Log in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _isRegisterMode = !_isRegisterMode;
                              _errorText = null;
                            }),
                      child: Text(
                        _isRegisterMode
                            ? 'Already have an account? Log in'
                            : "Don't have an account? Create one",
                      ),
                    ),
                    if (!widget.forcedReauth) ...[
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        child: const Text('Cancel'),
                      ),
                    ],
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
