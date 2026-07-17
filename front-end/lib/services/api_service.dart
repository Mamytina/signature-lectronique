import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {

  static const String baseUrl = "http://172.31.16.1:8000/api";
  static final _storage = const FlutterSecureStorage();

  // ---------------------------
  // LOGIN / REGISTER / TOKEN (inchangé)
  // ---------------------------
  static Future<Map<String,dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/token/"),
      headers: {"Content-Type":"application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      await _storage.write(key: "access_token", value: data["access"]);
      await _storage.write(key: "refresh_token", value: data["refresh"]);
      return data;
    } else {
      throw Exception(data["detail"] ?? "Login échoué");
    }
  }

  static Future<Map<String,dynamic>> register(
    String firstName, String lastName, String username,
    String email, String password, String confirmPassword,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register/"),
      headers: {"Content-Type":"application/json"},
      body: jsonEncode({
        "first_name": firstName, "last_name": lastName, "username": username,
        "email": email, "password": password, "confirm_password": confirmPassword,
      }),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception(response.body);
  }

  static Future<String?> getAccessToken() async => await _storage.read(key: "access_token");
  static Future<void> logout() async => await _storage.deleteAll();

  static Future<Map<String,String>> _authHeaders() async {
    final token = await getAccessToken();
    if (token == null) throw Exception("Utilisateur non connecté");
    return {"Authorization": "Bearer $token"};
  }

  // ---------------------------
  // USER INFO
  // ---------------------------
  static Future<Map<String,dynamic>> getMe() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/me/"), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors du chargement du profil");
  }

  static Future<Map<String,dynamic>> updateMe({String? firstName, String? lastName, String? email}) async {
    final headers = await _authHeaders();
    headers["Content-Type"] = "application/json";
    final response = await http.patch(
      Uri.parse("$baseUrl/me/"),
      headers: headers,
      body: jsonEncode({
        if (firstName != null) "first_name": firstName,
        if (lastName != null) "last_name": lastName,
        if (email != null) "email": email,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors de la mise à jour du profil");
  }

  // ---------------------------
  // SIGNATURE (bytes, marche pour fichier importé ET dessin)
  // ---------------------------
  static Future<Map<String,dynamic>> getSignature() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/signature/"), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors du chargement de la signature");
  }

  static Future<Map<String,dynamic>> updateSignature(Uint8List bytes, String fileName) async {
    final headers = await _authHeaders();

    final request = http.MultipartRequest("PATCH", Uri.parse("$baseUrl/signature/"))
      ..headers.addAll(headers)
      ..files.add(http.MultipartFile.fromBytes("signature", bytes, filename: fileName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors de l'envoi de la signature");
  }

  // ---------------------------
  // EMAIL HISTORY
  // ---------------------------
  static Future<List<dynamic>> getEmailHistory() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/email-history/"), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      if (data is Map && data.containsKey("results")) return data["results"];
      return [];
    }
    throw Exception("Erreur lors du chargement de l'historique");
  }

  // ---------------------------
  // DOCUMENTS (bytes au lieu de File — marche sur Web + Desktop + Mobile)
  // ---------------------------
  static Future<List<dynamic>> getDocuments() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/documents/"), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      if (data is Map && data.containsKey("results")) return data["results"];
      return [];
    } else if (response.statusCode == 401) {
      throw Exception("Session expirée, veuillez vous reconnecter");
    }
    throw Exception("Erreur lors du chargement des documents");
  }

  static Future<Map<String,dynamic>> createDocument(String title, Uint8List bytes, String fileName) async {
    final headers = await _authHeaders();

    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/documents/"))
      ..headers.addAll(headers)
      ..fields["title"] = title
      ..files.add(http.MultipartFile.fromBytes("file", bytes, filename: fileName));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception("Erreur lors de l'ajout du document : ${response.body}");
  }

  static Future<Map<String,dynamic>> updateDocument(int id, {String? title, Uint8List? bytes, String? fileName}) async {
    final headers = await _authHeaders();

    final request = http.MultipartRequest("PATCH", Uri.parse("$baseUrl/documents/$id/"))
      ..headers.addAll(headers);

    if (title != null) request.fields["title"] = title;
    if (bytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes("file", bytes, filename: fileName));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors de la modification : ${response.body}");
  }

  static Future<void> deleteDocument(int id) async {
    final headers = await _authHeaders();
    final response = await http.delete(Uri.parse("$baseUrl/documents/$id/"), headers: headers);
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception("Erreur lors de la suppression");
    }
  }


  // ---------------------------
  // DOCUMENT DETAIL / SUMMARIZE
  // ---------------------------
  static Future<Map<String,dynamic>> getDocumentDetail(int id) async {
  final response = await _authorizedGet("$baseUrl/documents/$id/");

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else if (response.statusCode == 401) {
    throw Exception("Session expirée, veuillez vous reconnecter");
  } else {
    throw Exception("Erreur lors du chargement du document");
  }
}

  static Future<Map<String,dynamic>> summarizeDocument(int id) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/documents/$id/summarize/"),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur lors du lancement du résumé");
    }
  }


  static Future<bool> _tryRefreshToken() async {
  final refreshToken = await _storage.read(key: "refresh_token");
  if (refreshToken == null) return false;

  final response = await http.post(
    Uri.parse("$baseUrl/token/refresh/"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"refresh": refreshToken}),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    await _storage.write(key: "access_token", value: data["access"]);
    return true;
  }
  return false;
}

static Future<http.Response> _authorizedGet(String url) async {
  var headers = await _authHeaders();
  var response = await http.get(Uri.parse(url), headers: headers);

  if (response.statusCode == 401) {
    final refreshed = await _tryRefreshToken();
    if (refreshed) {
      headers = await _authHeaders();
      response = await http.get(Uri.parse(url), headers: headers);
    }
  }

  return response;
}

static Future<Map<String,dynamic>> loginWithGoogle(String idToken) async {
  final response = await http.post(
    Uri.parse("$baseUrl/auth/google/"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({"id_token": idToken}),
  );

  final data = jsonDecode(response.body);

  if (response.statusCode == 200) {
    await _storage.write(key: "access_token", value: data["access"]);
    await _storage.write(key: "refresh_token", value: data["refresh"]);
    return data;
  } else {
    throw Exception(data["detail"] ?? "Connexion Google échouée");
  }
}
static Future<Uint8List> getSavedSignatureBytes() async {
    final sig = await getSignature();
    final url = sig["signature"];
    if (url == null) throw Exception("Aucune signature enregistrée");

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception("Impossible de récupérer la signature enregistrée");
  }

  static Future<Map<String,dynamic>> signDocument(
    int documentId, {
    required int page,
    required double x,
    required double y,
    required double width,
    Uint8List? signatureBytes,
    String? signatureFileName,
  }) async {
    final headers = await _authHeaders();

    final request = http.MultipartRequest(
      "POST", Uri.parse("$baseUrl/documents/$documentId/sign/"),
    )
      ..headers.addAll(headers)
      ..fields["page"] = page.toString()
      ..fields["x"] = x.toString()
      ..fields["y"] = y.toString()
      ..fields["width"] = width.toString();

    if (signatureBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        "signature_image", signatureBytes,
        filename: signatureFileName ?? "signature.png",
      ));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return jsonDecode(response.body);
    final data = jsonDecode(response.body);
    throw Exception(data["detail"] ?? "Erreur lors de la signature");
  }








  // ---------------------------
  // SIGNATURE PLACEMENT (preview + sign)
  // ---------------------------

  static Future<Uint8List> getPreviewImageBytes(int documentId, int page) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/documents/$documentId/preview/?page=$page"),
      headers: headers,
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception("Erreur lors du chargement de l'image");
  }



  // ---------------------------
  // PREVIEW
  // ---------------------------
  static Future<Map<String,dynamic>> getPreviewInfo(int id) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/documents/$id/preview_info/"),
      headers: headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors du chargement de l'aperçu");
  }

  static Future<Uint8List> getPreviewImage(int id, {int page = 0}) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/documents/$id/preview/?page=$page"),
      headers: headers,
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception("Erreur lors du chargement de l'image");
  }


  // ---------------------------
  // PREVIEW DOCUMENT SIGNÉ
  // ---------------------------
  static Future<Map<String,dynamic>> getSignedPreviewInfo(int id) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/documents/$id/preview_info/?source=signed"),
      headers: headers,
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    final data = jsonDecode(response.body);
    throw Exception(data["detail"] ?? "Erreur lors du chargement du document signé");
  }

  static Future<Uint8List> getSignedPreviewImageBytes(int id, int page) async {
    final headers = await _authHeaders();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await http.get(
      Uri.parse("$baseUrl/documents/$id/preview/?page=$page&source=signed&_t=$timestamp"),
      headers: headers,
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception("Erreur lors du chargement de la page");
  }


// ---------------------------
  // ENVOI EMAIL
  // ---------------------------
 static Future<Map<String,dynamic>> sendDocumentByEmail(
    int id,
    String recipientEmail, {
    String? message,
  }) async {
    final headers = await _authHeaders();
    headers["Content-Type"] = "application/json";
    final response = await http.post(
      Uri.parse("$baseUrl/documents/$id/send_email/"),
      headers: headers,
      body: jsonEncode({
        "recipient_email": recipientEmail,
        if (message != null && message.isNotEmpty) "message": message,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data["detail"] ?? "Erreur lors de l'envoi de l'email");
  }


  // ---------------------------
  // ADMIN
  // ---------------------------
  static Future<Map<String,dynamic>> getAdminStats() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/admin/stats/"), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Erreur lors du chargement des statistiques");
  }

  static Future<List<dynamic>> getAdminUsers() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/admin/users/"), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      if (data is Map && data.containsKey("results")) return data["results"];
      return [];
    }
    throw Exception("Erreur lors du chargement des utilisateurs");
  }

  static Future<Map<String,dynamic>> toggleUserActive(int userId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/admin/users/$userId/toggle-active/"),
      headers: headers,
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data["detail"] ?? "Erreur lors de la modification");
  }

  static Future<List<dynamic>> getAdminDocuments() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/admin/documents/"), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) return data;
      if (data is Map && data.containsKey("results")) return data["results"];
      return [];
    }
    throw Exception("Erreur lors du chargement des documents");
  }
}


