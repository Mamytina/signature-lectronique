import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'user_info_page.dart';
import 'document_detail_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {

  List<dynamic> documents = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  void loadDocuments() async {
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final result = await ApiService.getDocuments();
      setState(() { documents = result; isLoading = false; });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });

      if (errorMessage!.contains("Session expirée") || errorMessage!.contains("non connecté")) {
        _redirectToLogin();
      }
    }
  }

  void _redirectToLogin() {
    Future.microtask(() {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    });
  }

  void logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ---------------------------
  // AJOUT / MODIFICATION D'UN DOCUMENT
  // ---------------------------
 

void showDocumentDialog({Map<String,dynamic>? existing}) {
  final titleController = TextEditingController(text: existing?["title"] ?? "");
  Uint8List? pickedBytes;
  String? pickedFileName;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(existing == null ? "Ajouter un document" : "Modifier le document"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Titre"),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: Text(pickedFileName ??
                        (existing != null ? "Remplacer le fichier (optionnel)" : "Choisir un fichier")),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        withData: true, // <-- IMPORTANT pour Web
                      );
                      if (result != null && result.files.single.bytes != null) {
                        setDialogState(() {
                          pickedBytes = result.files.single.bytes;
                          pickedFileName = result.files.single.name;
                        });
                      }
                    },
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
                onPressed: () async {
                  if (titleController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Le titre est requis")),
                    );
                    return;
                  }
                  if (existing == null && pickedBytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Veuillez choisir un fichier")),
                    );
                    return;
                  }

                  Navigator.pop(context);

                  try {
                    if (existing == null) {
                      await ApiService.createDocument(
                        titleController.text, pickedBytes!, pickedFileName!,
                      );
                    } else {
                      await ApiService.updateDocument(
                        existing["id"],
                        title: titleController.text,
                        bytes: pickedBytes,
                        fileName: pickedFileName,
                      );
                    }
                    loadDocuments();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                    );
                  }
                },
                child: Text(existing == null ? "Ajouter" : "Enregistrer"),
              ),
            ],
          );
        },
      );
    },
  );
}

  void deleteDocument(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Supprimer"),
        content: const Text("Voulez-vous vraiment supprimer ce document ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.deleteDocument(id);
      loadDocuments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes documents"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: "Mon profil",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserInfoPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Déconnexion",
            onPressed: logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => loadDocuments(),
        child: buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDocumentDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: loadDocuments, child: const Text("Réessayer")),
          ],
        ),
      );
    }

    if (documents.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text("Aucun document. Appuyez sur + pour en ajouter un.")),
        ],
      );
    }

    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];

        return ListTile(
          leading: const Icon(Icons.description),
          title: Text(doc["title"] ?? "Sans titre"),
          subtitle: Text("Statut : ${doc["status"] ?? "-"}"),
          trailing: PopupMenuButton<String>(onSelected: (value) {
          if (value == "view") {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: doc["id"])),
            ).then((_) => loadDocuments()); // rafraîchit au retour
          } else if (value == "edit") {
            showDocumentDialog(existing: doc);
          } else if (value == "delete") {
            deleteDocument(doc["id"]);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: "view", child: Text("Voir")),
          const PopupMenuItem(value: "edit", child: Text("Modifier")),
          const PopupMenuItem(value: "delete", child: Text("Supprimer")),
        ],
      ),
        );
      },
    );
  }
}