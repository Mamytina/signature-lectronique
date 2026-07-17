import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'sign_document_page.dart';
import 'view_signed_document_page.dart';

class DocumentDetailPage extends StatefulWidget {
  final int documentId;
  const DocumentDetailPage({super.key, required this.documentId});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {

  Map<String, dynamic>? document;
  bool isLoading = true;
  bool isSummarizing = false;
  String? errorMessage;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    loadDocument();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void loadDocument() async {
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final data = await ApiService.getDocumentDetail(widget.documentId);
      setState(() {
        document = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void startSummarize() async {
    setState(() => isSummarizing = true);

    try {
      final result = await ApiService.summarizeDocument(widget.documentId);

      // Si déjà résumé (status == completed), on affiche directement
      if (result["status"] == "completed") {
        setState(() {
          document?["summary"] = result["summary"];
          document?["status"] = "completed";
          isSummarizing = false;
        });
        _showSummaryPopup(result["summary"]);
        return;
      }

      // Sinon on lance le polling toutes les 3 secondes
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        try {
          final updated = await ApiService.getDocumentDetail(widget.documentId);

          if (updated["status"] == "completed") {
            timer.cancel();
            setState(() {
              document = updated;
              isSummarizing = false;
            });
            _showSummaryPopup(updated["summary"]);
          } else if (updated["status"] != "processing") {
            // sécurité si erreur/autre statut inattendu
            timer.cancel();
            setState(() {
              document = updated;
              isSummarizing = false;
            });
          }
        } catch (_) {
          // on ignore les erreurs de polling ponctuelles
        }
      });

    } catch (e) {
      setState(() => isSummarizing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  void _showSummaryPopup(String? summary) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Résumé du document"),
        content: SingleChildScrollView(
          child: Text(summary ?? "Aucun résumé disponible"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
    // Le résumé est déjà enregistré côté backend (process_document_task),
    // donc rien de plus à faire ici pour la persistance.
  }

  void openSignPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignDocumentPage(documentId: widget.documentId),
      ),
    );

    // Si la signature a été validée, on recharge le document
    if (result != null) {
      loadDocument();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Détail du document")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : RefreshIndicator(
                  onRefresh: () async => loadDocument(),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        document?["title"] ?? "Sans titre",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text("Statut : ${document?["status"] ?? "-"}"),
                      const SizedBox(height: 8),
                      if (document?["uploaded_at"] != null)
                        Text("Ajouté le : ${document!["uploaded_at"]}"),
                      const Divider(height: 32),

                      const Text("Résumé", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      if (document?["summary"] != null && document!["summary"].toString().isNotEmpty)
                        Text(document!["summary"])
                      else
                        const Text("Aucun résumé pour le moment"),

                      const SizedBox(height: 16),

                      isSummarizing
                          ? Row(
                              children: const [
                                SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text("Résumé en cours..."),
                              ],
                            )
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.summarize),
                              label: Text(
                                (document?["summary"] != null && document!["summary"].toString().isNotEmpty)
                                    ? "Revoir le résumé"
                                    : "Résumer le document",
                              ),
                              onPressed: () {
                                if (document?["summary"] != null && document!["summary"].toString().isNotEmpty) {
                                  _showSummaryPopup(document!["summary"]);
                                } else {
                                  startSummarize();
                                }
                              },
                            ),

                      const Divider(height: 32),

                      const Text("Signature", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),

                      if (document?["status"] == "signed")
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text("Document signé"),
                              ],
                            ),
                            const SizedBox(height: 12),
                           if (document?["signed_file"] != null)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.picture_as_pdf),
                                label: const Text("Voir le document signé"),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ViewSignedDocumentPage(
                                        documentId: widget.documentId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.draw),
                          label: const Text("Signer le document"),
                          onPressed: openSignPage,
                        ),
                    ],
                  ),
                ),
    );
  }
}