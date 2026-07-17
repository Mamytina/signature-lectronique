import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'user_info_page.dart';
import 'document_detail_page.dart';
import 'admin_dashboard_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  List<dynamic> documents = [];
  bool isLoading = true;
  String? errorMessage;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    loadDocuments();
    checkAdmin();
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

  void checkAdmin() async {
    try {
      final me = await ApiService.getMe();
      if (!mounted) return;
      setState(() => isAdmin = me["is_staff"] == true);
    } catch (_) {}
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
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              title: Text(
                existing == null ? "Ajouter un document" : "Modifier le document",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Titre"),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text(pickedFileName ??
                          (existing != null ? "Remplacer le fichier (optionnel)" : "Choisir un fichier")),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(withData: true);
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
                  style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text("Supprimer", style: Theme.of(context).textTheme.headlineSmall),
        content: const Text(
          "Voulez-vous vraiment supprimer ce document ?",
          style: TextStyle(color: AppColors.slate),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text("Supprimer"),
          ),
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
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text("Mes documents", style: Theme.of(context).textTheme.headlineSmall),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, color: AppColors.ink),
              tooltip: "Dashboard Admin",
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppColors.ink),
            tooltip: "Mon profil",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserInfoPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.slate),
            tooltip: "Déconnexion",
            onPressed: logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.brass,
        onRefresh: () async => loadDocuments(),
        child: buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDocumentDialog(),
        backgroundColor: AppColors.ink,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brass, strokeWidth: 2),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: loadDocuments, child: const Text("Réessayer")),
            ],
          ),
        ),
      );
    }

    if (documents.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 140),
          Icon(Icons.draw_outlined, size: 40, color: AppColors.line),
          const SizedBox(height: 16),
          Center(
            child: Text(
              "Aucun document pour l'instant",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              "Touchez + pour en ajouter un",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: documents.length,
      separatorBuilder: (_, __) => const Divider(color: AppColors.line, height: 1, indent: 24, endIndent: 24),
      itemBuilder: (context, index) {
        final doc = documents[index];
        final isSigned = doc["status"] == "signed";
        final statusLabel = _statusLabel(doc["status"]);
        final statusColor = isSigned ? AppColors.brass : AppColors.slate;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DocumentDetailPage(documentId: doc["id"])),
            ).then((_) => loadDocuments());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc["title"] ?? "Sans titre",
                        style: const TextStyle(fontSize: 15, color: AppColors.inkDark, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Text(statusLabel, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.slate, size: 20),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onSelected: (value) {
                    if (value == "edit") {
                      showDocumentDialog(existing: doc);
                    } else if (value == "delete") {
                      deleteDocument(doc["id"]);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: "edit", child: Text("Modifier")),
                    const PopupMenuItem(
                      value: "delete",
                      child: Text("Supprimer", style: TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case "signed":
        return "Signé";
      case "completed":
        return "Résumé prêt";
      case "processing":
        return "Traitement en cours";
      default:
        return "En attente";
    }
  }
}