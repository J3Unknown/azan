import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:azan/services/community_service.dart';
import 'package:azan/utils/helpers/app_language.dart';

enum AuthPage { login, signup }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.page = AuthPage.login, this.authClient});
  final AuthPage page;
  final GoTrueClient? authClient;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  GoTrueClient get auth => widget.authClient ?? CommunityService.client.auth;
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? message;
  late AuthPage page = widget.page;
  bool get signup => page == AuthPage.signup;
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
      if (signup) {
        final result = await auth.signUp(
          email: email.text.trim(),
          password: password.text,
          data: {'display_name': name.text.trim()},
        );
        if (result.session == null) {
          debugPrint(
            'Signup returned no session. Email confirmation must be disabled for this app.',
          );
          message =
              'Sign up is temporarily unavailable. Please try again later.';
          return;
        }
        await auth.signOut(scope: SignOutScope.local);
        if (mounted) {
          final signupEmail = email.text.trim();
          form.currentState!.reset();
          email.text = signupEmail;
          password.clear();
          setState(() {
            page = AuthPage.login;
            message = 'Account created successfully. Please sign in.';
          });
        }
        return;
      } else {
        await auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (mounted) Navigator.pop(context);
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
    final title = signup ? 'Sign up' : 'Log in';
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
                  if (signup)
                    TextFormField(
                      key: const ValueKey('name'),
                      controller: name,
                      maxLength: 50,
                      decoration: InputDecoration(
                        labelText: context.tr('Full name'),
                      ),
                      validator: (v) => (v?.trim().length ?? 0) < 2
                          ? context.tr('Use at least 2 characters')
                          : null,
                    ),
                  TextFormField(
                    key: const ValueKey('email'),
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: InputDecoration(labelText: context.tr('Email')),
                    validator: (v) {
                      final error = CommunityService.emailError(v);
                      return error == null ? null : context.tr(error);
                    },
                  ),
                  TextFormField(
                    key: const ValueKey('password'),
                    controller: password,
                    obscureText: obscure,
                    autofillHints: [
                      signup
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
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
                    validator: (v) => signup
                        ? ((v?.length ?? 0) < 8
                              ? context.tr('Use at least 8 characters')
                              : null)
                        : ((v?.isEmpty ?? true)
                              ? context.tr('Required')
                              : null),
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
                  if (!signup)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              final loginEmail = email.text.trim();
                              form.currentState!.reset();
                              email.text = loginEmail;
                              password.clear();
                              message = null;
                              page = AuthPage.signup;
                            }),
                      child: Text(context.tr('Create an account')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
