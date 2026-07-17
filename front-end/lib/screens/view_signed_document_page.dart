import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';

class ViewSignedDocumentPage extends StatefulWidget {
  final int documentId;
  const ViewSignedDocumentPage({super.key, required this.documentId});

  @override
  State<ViewSignedDocumentPage> createState() => _ViewSignedDocumentPageState();
}

class _ViewSignedDocumentPageState extends State<ViewSignedDocumentPage> {
  bool isLoading = true;
  bool isSendingEmail = false;
  String? errorMessage;
  int pageCount = 0;
  int currentPage = 0;
  String? signedFileUrl;
  String? existingRecipientEmail;

  final Map<int, Uint8List> _pageCache = {};
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    loadInfo();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void loadInfo() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final info = await ApiService.getSignedPreviewInfo(widget.documentId);
      final detail = await ApiService.getDocumentDetail(widget.documentId);

      setState(() {
        pageCount = info["page_count"];
        currentPage = 0;
        signedFileUrl = detail["signed_file"];
        existingRecipientEmail = detail["recipient_email"];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  Future<Uint8List> _loadPage(int index) async {
    if (_pageCache.containsKey(index)) return _pageCache[index]!;
    final bytes = await ApiService.getSignedPreviewImageBytes(widget.documentId, index);
    _pageCache[index] = bytes;
    return bytes;
  }

  // ---------------------------
  // TÉLÉCHARGEMENT
  // ---------------------------
  Future<void> downloadDocument() async {
    if (signedFileUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fichier signé introuvable")),
      );
      return;
    }

    final uri = Uri.parse(signedFileUrl!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir le fichier")),
      );
    }
  }

  // ---------------------------
  // ENVOI PAR EMAIL
  // ---------------------------
   void showSendEmailDialog() {
    final emailController = TextEditingController(text: existingRecipientEmail ?? "");
    final messageController = TextEditingController(text: "C'est signé ✅");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Envoyer par email"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Adresse email du destinataire",
                hintText: "exemple@email.com",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Petit mot (optionnel)",
                hintText: "C'est signé !",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains("@")) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Veuillez saisir une adresse email valide")),
                );
                return;
              }
              Navigator.pop(context);
              await sendEmail(email, messageController.text.trim());
            },
            child: const Text("Envoyer"),
          ),
        ],
      ),
    );
  }

  Future<void> sendEmail(String recipientEmail, String message) async {
    setState(() => isSendingEmail = true);
    try {
      await ApiService.sendDocumentByEmail(
        widget.documentId,
        recipientEmail,
        message: message,
      );
      if (!mounted) return;
      setState(() => existingRecipientEmail = recipientEmail);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Document envoyé à $recipientEmail")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isSendingEmail = false);
    }
  }

 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pageCount > 0 ? "Page ${currentPage + 1} / $pageCount" : "Document signé"),
        actions: (!isLoading && errorMessage == null)
            ? [
                IconButton(
                  icon: isSendingEmail
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.email_outlined),
                  tooltip: "Envoyer par email",
                  onPressed: isSendingEmail ? null : showSendEmailDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: "Télécharger",
                  onPressed: downloadDocument,
                ),
              ]
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: loadInfo, child: const Text("Réessayer")),
                      ],
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: pageCount,
                  onPageChanged: (index) => setState(() => currentPage = index),
                  itemBuilder: (context, index) {
                    return FutureBuilder<Uint8List>(
                      future: _loadPage(index),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return const Center(child: Text("Impossible de charger cette page"));
                        }
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                          ),
                        );
                      },
                    );
                  },
                ),
      bottomNavigationBar: (!isLoading && errorMessage == null && pageCount > 1)
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: currentPage > 0
                        ? () => _pageController.previousPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            )
                        : null,
                  ),
                  Text("${currentPage + 1} / $pageCount"),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: currentPage < pageCount - 1
                        ? () => _pageController.nextPage(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                            )
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}