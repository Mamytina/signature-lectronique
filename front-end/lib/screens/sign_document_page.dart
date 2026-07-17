import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:signature/signature.dart';
import '../services/api_service.dart';

class SignDocumentPage extends StatefulWidget {
  final int documentId;
  const SignDocumentPage({super.key, required this.documentId});

  @override
  State<SignDocumentPage> createState() => _SignDocumentPageState();
}

class _SignDocumentPageState extends State<SignDocumentPage> {

  bool isLoading = true;
  bool isSigning = false;
  String? errorMessage;

  Uint8List? previewBytes;
  int page = 0;
  double pageWidth = 1;
  double pageHeight = 1;

  Uint8List? placedSignatureBytes;
  String? placedSignatureFileName;
  double? tapX; // normalisé 0-1 (centre de la signature)
  double? tapY;
  final double sigWidthRatio = 0.28;

  final SignatureController _sigController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _sigController.dispose();
    super.dispose();
  }

  void loadData() async {
    setState(() { isLoading = true; errorMessage = null; });

    try {
      final info = await ApiService.getPreviewInfo(widget.documentId);
      page = info["suggested_page"];
      pageWidth = (info["page_width"] as num).toDouble();
      pageHeight = (info["page_height"] as num).toDouble();

      final bytes = await ApiService.getPreviewImageBytes(widget.documentId, page);

      setState(() {
        previewBytes = bytes;
        isLoading = false;
      });

    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void onTapAt(double xRatio, double yRatio) {
    setState(() {
      tapX = xRatio.clamp(0.0, 1.0);
      tapY = yRatio.clamp(0.0, 1.0);
    });
    showSignatureOptions();
  }

  void showSignatureOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.badge),
              title: const Text("Utiliser ma signature enregistrée"),
              onTap: () async {
                Navigator.pop(context);
                await useSavedSignature();
              },
            ),
            ListTile(
              leading: const Icon(Icons.draw),
              title: const Text("Dessiner une signature"),
              onTap: () {
                Navigator.pop(context);
                openDrawDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text("Importer une image"),
              onTap: () async {
                Navigator.pop(context);
                await pickImportedSignature();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> useSavedSignature() async {
    try {
      final bytes = await ApiService.getSavedSignatureBytes();
      setState(() {
        placedSignatureBytes = bytes;
        placedSignatureFileName = "signature.png";
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> pickImportedSignature() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() {
      placedSignatureBytes = result.files.single.bytes;
      placedSignatureFileName = result.files.single.name;
    });
  }

  void openDrawDialog() {
    _sigController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              if (_sigController.isEmpty) return;
              final bytes = await _sigController.toPngBytes();
              if (bytes == null) return;
              Navigator.pop(context);
              setState(() {
                placedSignatureBytes = bytes;
                placedSignatureFileName = "signature.png";
              });
            },
            child: const Text("Utiliser"),
          ),
        ],
      ),
    );
  }

  void confirmSign() async {
    if (placedSignatureBytes == null || tapX == null || tapY == null) return;

    setState(() => isSigning = true);
    try {
      final result = await ApiService.signDocument(
        widget.documentId,
        page: page,
        x: tapX!,
        y: tapY!,
        width: sigWidthRatio,
        signatureBytes: placedSignatureBytes,
        signatureFileName: placedSignatureFileName,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Document signé avec succès")),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isSigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Signer le document")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(errorMessage!, textAlign: TextAlign.center),
                ))
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        "Touchez l'endroit où vous voulez apposer votre signature.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: pageWidth / pageHeight,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final boxW = constraints.maxWidth;
                              final boxH = constraints.maxHeight;
                              final sigHeightRatio = sigWidthRatio * boxW / boxH * (pageWidth / pageHeight);

                              return GestureDetector(
                                onTapUp: (details) {
                                  final local = details.localPosition;
                                  onTapAt(local.dx / boxW, local.dy / boxH);
                                },
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Image.memory(previewBytes!, fit: BoxFit.contain),
                                    ),
                                    if (placedSignatureBytes != null && tapX != null && tapY != null)
                                      Positioned(
                                        left: (tapX! - sigWidthRatio / 2) * boxW,
                                        top: (tapY! - sigHeightRatio / 2) * boxH,
                                        width: sigWidthRatio * boxW,
                                        child: GestureDetector(
                                          onPanUpdate: (details) {
                                            setState(() {
                                              tapX = (tapX! + details.delta.dx / boxW).clamp(0.0, 1.0);
                                              tapY = (tapY! + details.delta.dy / boxH).clamp(0.0, 1.0);
                                            });
                                          },
                                          onTap: showSignatureOptions, // retaper la signature pour changer de source
                                          child: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.blue),
                                            ),
                                            child: Image.memory(placedSignatureBytes!),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: isSigning
                          ? const CircularProgressIndicator()
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text("Valider la signature"),
                              onPressed: placedSignatureBytes == null ? null : confirmSign,
                            ),
                    ),
                  ],
                ),
    );
  }
}