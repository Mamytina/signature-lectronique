import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {

  static const String baseUrl = "http://127.0.0.1:8000/api";
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
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse("$baseUrl/documents/$id/"), headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
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
}