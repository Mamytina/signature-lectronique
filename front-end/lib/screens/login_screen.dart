import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/signature_flourish.dart';
import 'user_home_page.dart';
import 'register_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool obscurePassword = true;
  String? errorMessage;

  static const String _webClientId =
      "830510299154-hlo0f892j7vd278m8itrj1h91e32qdoa.apps.googleusercontent.com";

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email', 'openid', 'profile'],
  clientId: kIsWeb ? _webClientId : null,
  serverClientId: kIsWeb ? null : _webClientId,
);

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      setState(() => errorMessage = "Renseignez votre email et votre mot de passe");
      return;
    }

    setState(() { isLoading = true; errorMessage = null; });

    try {
      await ApiService.login(emailController.text.trim(), passwordController.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserHomePage()),
        (route) => false,
      );
    } catch (e) {
      setState(() => errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() { isGoogleLoading = true; errorMessage = null; });

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        setState(() => isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        throw Exception("Connexion Google incomplète, réessayez");
      }

      await ApiService.loginWithGoogle(idToken);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserHomePage()),
        (route) => false,
      );
    } catch (e) {
      setState(() => errorMessage = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("docsigne", style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 6),
                  const SignatureFlourish(width: 110),
                  const SizedBox(height: 18),
                  Text(
                    "Signez vos documents, simplement.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: AppColors.error, width: 3)),
                      ),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 15, color: AppColors.inkDark),
                    decoration: const InputDecoration(labelText: "Adresse email"),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    style: const TextStyle(fontSize: 15, color: AppColors.inkDark),
                    decoration: InputDecoration(
                      labelText: "Mot de passe",
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20, color: AppColors.slate,
                        ),
                        onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      ),
                    ),
                    onSubmitted: (_) => login(),
                  ),
                  const SizedBox(height: 40),

                  ElevatedButton(
                    onPressed: isLoading ? null : login,
                    child: isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Se connecter"),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.line, height: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text("ou", style: Theme.of(context).textTheme.bodySmall),
                      ),
                      const Expanded(child: Divider(color: AppColors.line, height: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  OutlinedButton(
                    onPressed: isGoogleLoading ? null : signInWithGoogle,
                    child: isGoogleLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.fromBorderSide(BorderSide(color: AppColors.ink, width: 1.2)),
                                ),
                                alignment: Alignment.center,
                                child: const Text("G", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)),
                              ),
                              const SizedBox(width: 10),
                              const Text("Continuer avec Google"),
                            ],
                          ),
                  ),
                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Pas encore de compte ?", style: Theme.of(context).textTheme.bodyMedium),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        ),
                        child: const Text("S'inscrire"),
                      ),
                    ],
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