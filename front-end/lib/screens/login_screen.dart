import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // LOGIN
  final loginEmail = TextEditingController();
  final loginPassword = TextEditingController();

  // REGISTER
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final registerUsername = TextEditingController();
  final email = TextEditingController();
  final registerPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    loginEmail.dispose();
    loginPassword.dispose();
    firstName.dispose();
    lastName.dispose();
    registerUsername.dispose();
    email.dispose();
    registerPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  void login() async {
    if (loginEmail.text.isEmpty || loginPassword.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir tous les champs")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ApiService.login(
        loginEmail.text.trim(),
        loginPassword.text,
      );

      print("Connexion réussie : $result");

      if (!mounted) return;

      //Redirection vers la page d'accueil après connexion
         Navigator.pushReplacement(
          context,
       MaterialPageRoute(builder: (_) => const UserHomePage()),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connexion réussie")),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString().replaceAll('Exception: ', '')}")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void register() async {
    setState(() => isLoading = true);

    try {
      final result = await ApiService.register(
        firstName.text,
        lastName.text,
        registerUsername.text,
        email.text,
        registerPassword.text,
        confirmPassword.text,
      );

      print("Inscription réussie : $result");

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Compte créé avec succès")),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : ${e.toString().replaceAll('Exception: ', '')}")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showRegisterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Créer un compte"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstName,
                  decoration: const InputDecoration(labelText: "Nom"),
                ),
                TextField(
                  controller: lastName,
                  decoration: const InputDecoration(labelText: "Prénom"),
                ),
                TextField(
                  controller: registerUsername,
                  decoration: const InputDecoration(labelText: "Pseudo"),
                ),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                TextField(
                  controller: registerPassword,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Mot de passe"),
                ),
                TextField(
                  controller: confirmPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Confirmation mot de passe",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                if (registerPassword.text != confirmPassword.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Les mots de passe ne correspondent pas"),
                    ),
                  );
                  return;
                }
                Navigator.pop(context); // ferme le dialog
                register();
              },
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connexion")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: loginEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: loginPassword,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    child: const Text("Connexion"),
                  ),
            TextButton(
              onPressed: isLoading ? null : showRegisterDialog,
              child: const Text("Créer un compte"),
            ),
          ],
        ),
      ),
    );
  }
}