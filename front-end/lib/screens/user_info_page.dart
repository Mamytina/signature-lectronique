import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import '../services/api_service.dart';

class UserInfoPage extends StatefulWidget {
  const UserInfoPage({super.key});

  @override
  State<UserInfoPage> createState() => _UserInfoPageState();
}

class _UserInfoPageState extends State<UserInfoPage> {

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();

  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingSignature = false;
  String? errorMessage;
  String? signatureUrl;
  List<dynamic> emailHistory = [];

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  void loadAll() async {
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final me = await ApiService.getMe();
      firstNameController.text = me["first_name"] ?? "";
      lastNameController.text = me["last_name"] ?? "";
      emailController.text = me["email"] ?? "";

      try {
        final sig = await ApiService.getSignature();
        signatureUrl = sig["signature"];
      } catch (_) {}

      try {
        emailHistory = await ApiService.getEmailHistory();
      } catch (_) {}

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void saveProfile() async {
    setState(() => isSaving = true);
    try {
      await ApiService.updateMe(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        email: emailController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profil mis à jour")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ---------------------------
  // Signature : import fichier
  // ---------------------------
  void pickSignatureFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // important pour Web
    );
    if (result == null || result.files.single.bytes == null) return;

    await _uploadSignatureBytes(
      result.files.single.bytes!,
      result.files.single.name,
    );
  }

  // ---------------------------
  // Signature : dessin
  // ---------------------------
  void showDrawSignatureDialog() {
    _sigController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Dessiner votre signature"),
          content: SizedBox(
            width: 350,
            height: 200,
            child: Signature(
              controller: _sigController,
              backgroundColor: Colors.grey[200]!,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _sigController.clear(),
              child: const Text("Effacer"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_sigController.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Veuillez dessiner une signature")),
                  );
                  return;
                }

                final Uint8List? pngBytes = await _sigController.toPngBytes();
                if (pngBytes == null) return;

                Navigator.pop(context);
                await _uploadSignatureBytes(pngBytes, "signature.png");
              },
              child: const Text("Enregistrer"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadSignatureBytes(Uint8List bytes, String fileName) async {
    setState(() => isUploadingSignature = true);
    try {
      final data = await ApiService.updateSignature(bytes, fileName);
      setState(() => signatureUrl = data["signature"]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signature mise à jour")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isUploadingSignature = false);
    }
  }

  void showSignatureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text("Importer une image"),
              onTap: () {
                Navigator.pop(context);
                pickSignatureFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.draw),
              title: const Text("Dessiner ma signature"),
              onTap: () {
                Navigator.pop(context);
                showDrawSignatureDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mon profil")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : RefreshIndicator(
                  onRefresh: () async => loadAll(),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text("Informations personnelles",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: firstNameController,
                        decoration: const InputDecoration(labelText: "Prénom"),
                      ),
                      TextField(
                        controller: lastNameController,
                        decoration: const InputDecoration(labelText: "Nom"),
                      ),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: "Email"),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: isSaving ? null : saveProfile,
                        child: isSaving
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text("Enregistrer"),
                      ),

                      const Divider(height: 40),

                      const Text("Signature",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      if (signatureUrl != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                          child: Image.network(signatureUrl!, height: 100),
                        )
                      else
                        const Text("Aucune signature enregistrée"),

                      const SizedBox(height: 12),

                      isUploadingSignature
                          ? const CircularProgressIndicator()
                          : OutlinedButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text("Ajouter / modifier la signature"),
                              onPressed: showSignatureOptions,
                            ),

                      const Divider(height: 40),

                      const Text("Historique des emails",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (emailHistory.isEmpty)
                        const Text("Aucun email envoyé pour le moment")
                      else
                        ...emailHistory.map((h) => ListTile(
                              leading: Icon(
                                h["status"] == "sent" ? Icons.check_circle : Icons.error,
                                color: h["status"] == "sent" ? Colors.green : Colors.red,
                              ),
                              title: Text(h["subject"] ?? ""),
                              subtitle: Text("${h["recipient_email"]} — ${h["document_title"] ?? ""}"),
                              trailing: Text(h["status"] ?? ""),
                            )),
                    ],
                  ),
                ),
    );
  }
}