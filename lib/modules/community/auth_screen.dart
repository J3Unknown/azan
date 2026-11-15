import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';
import 'package:go_router/go_router.dart';

enum AuthPage { login, signup, forgot, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.page = AuthPage.login});
  final AuthPage page;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? message;
  late AuthPage page = widget.page;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = CommunityService.client.auth;
      switch (page) {
        case AuthPage.login:
          await auth.signInWithPassword(
            email: email.text.trim(),
            password: password.text,
          );
          if (mounted) Navigator.pop(context);
        case AuthPage.signup:
          final result = await auth.signUp(
            email: email.text.trim(),
            password: password.text,
            data: {'display_name': name.text.trim()},
            emailRedirectTo: CommunityService.redirect,
          );
          if (result.session != null && mounted) {
            Navigator.pop(context);
          } else {
            message = 'Check your email to confirm registration, then log in.';
          }
        case AuthPage.forgot:
          await auth.resetPasswordForEmail(
            email.text.trim(),
            redirectTo: CommunityService.redirect,
          );
          message = 'If this account exists, a reset link has been sent.';
        case AuthPage.reset:
          await auth.updateUser(UserAttributes(password: password.text));
          if (mounted) context.go('/home');
      }
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Unable to connect. Please try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resendConfirmation() async {
    final error = CommunityService.emailError(email.text);
    if (error != null) {
      setState(() => message = error);
      return;
    }
    setState(() => busy = true);
    try {
      await CommunityService.client.auth.resend(
        type: OtpType.signup,
        email: email.text.trim(),
        emailRedirectTo: CommunityService.redirect,
      );
      message = 'Check your email to confirm registration, then log in.';
    } on AuthException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'Unable to connect. Please try again.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (page) {
      AuthPage.login => 'Log in',
      AuthPage.signup => 'Sign up',
      AuthPage.forgot => 'Forgot password',
      AuthPage.reset => 'Set new password',
    };
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(title))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mosque_outlined, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('Grow together, one good deed at a time.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (page == AuthPage.signup)
                    TextFormField(
                      controller: name,
                      maxLength: 50,
                      decoration: InputDecoration(
                        labelText: context.tr('User name'),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? context.tr('Use at least 2 characters')
                          : null,
                    ),
                  if (page != AuthPage.reset)
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: context.tr('Email'),
                      ),
                      validator: (v) {
                        final error = CommunityService.emailError(v);
                        return error == null ? null : context.tr(error);
                      },
                    ),
                  if (page != AuthPage.forgot)
                    TextFormField(
                      controller: password,
                      obscureText: obscure,
                      decoration: InputDecoration(
                        labelText: context.tr('Password'),
                        suffixIcon: IconButton(
                          tooltip: context.tr('Show password'),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => obscure = !obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v?.length ?? 0) < (page == AuthPage.login ? 1 : 8)
                          ? context.tr('Use at least 8 characters')
                          : null,
                    ),
                  const SizedBox(height: 24),
                  if (message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        context.tr(message!),
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr(title)),
                  ),
                  if (page == AuthPage.login) ...[
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AuthScreen(page: AuthPage.signup),
                                ),
                              );
                              if (context.mounted &&
                                  CommunityService.client.auth.currentSession !=
                                      null) {
                                Navigator.pop(context);
                              }
                            },
                      child: Text(context.tr('Create an account')),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const AuthScreen(page: AuthPage.forgot),
                              ),
                            ),
                      child: Text(context.tr('Forgot password')),
                    ),
                    TextButton(
                      onPressed: busy ? null : resendConfirmation,
                      child: Text(context.tr('Resend confirmation email')),
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
