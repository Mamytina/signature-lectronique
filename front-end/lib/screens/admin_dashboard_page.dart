import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? stats;
  List<dynamic> users = [];
  List<dynamic> documents = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void loadAll() async {
    setState(() { isLoading = true; errorMessage = null; });
    try {
      final results = await Future.wait([
        ApiService.getAdminStats(),
        ApiService.getAdminUsers(),
        ApiService.getAdminDocuments(),
      ]);
      setState(() {
        stats = results[0] as Map<String, dynamic>;
        users = results[1] as List<dynamic>;
        documents = results[2] as List<dynamic>;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
    }
  }

  void toggleUser(int userId) async {
    try {
      final result = await ApiService.toggleUserActive(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result["message"])),
      );
      loadAll();
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
        title: const Text("Dashboard Admin"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart), text: "Stats"),
            Tab(icon: Icon(Icons.people), text: "Utilisateurs"),
            Tab(icon: Icon(Icons.description), text: "Documents"),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(errorMessage!),
                      const SizedBox(height: 10),
                      ElevatedButton(onPressed: loadAll, child: const Text("Réessayer")),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async => loadAll(),
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      buildStatsTab(),
                      buildUsersTab(),
                      buildDocumentsTab(),
                    ],
                  ),
                ),
    );
  }

  Widget buildStatsTab() {
    if (stats == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _statCard("Utilisateurs", stats!["total_users"].toString(), Icons.people, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(child: _statCard("Actifs", stats!["active_users"].toString(), Icons.check_circle, Colors.green)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statCard("Documents", stats!["total_documents"].toString(), Icons.description, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(child: _statCard("Emails envoyés", stats!["total_emails_sent"].toString(), Icons.email, Colors.purple)),
          ],
        ),
        const SizedBox(height: 24),
        const Text("Documents par statut", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...((stats!["documents_by_status"] as Map<String, dynamic>).entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key),
                Text(e.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget buildUsersTab() {
    if (users.isEmpty) {
      return const Center(child: Text("Aucun utilisateur"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isActive = user["is_active"] == true;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green[100] : Colors.red[100],
              child: Icon(
                isActive ? Icons.person : Icons.person_off,
                color: isActive ? Colors.green : Colors.red,
              ),
            ),
            title: Text("${user["first_name"] ?? ""} ${user["last_name"] ?? ""}".trim().isEmpty
                ? user["username"]
                : "${user["first_name"]} ${user["last_name"]}"),
            subtitle: Text("${user["email"]}\n${user["document_count"]} document(s)"),
            isThreeLine: true,
            trailing: Switch(
              value: isActive,
              onChanged: (_) => toggleUser(user["id"]),
            ),
          ),
        );
      },
    );
  }

  Widget buildDocumentsTab() {
    if (documents.isEmpty) {
      return const Center(child: Text("Aucun document"));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.description),
            title: Text(doc["title"] ?? "Sans titre"),
            subtitle: Text(
              "Par ${doc["owner_username"]} (${doc["owner_email"]})\nStatut : ${doc["status"]}",
            ),
            isThreeLine: true,
            trailing: Icon(
              doc["status"] == "signed" ? Icons.verified : Icons.pending_outlined,
              color: doc["status"] == "signed" ? Colors.green : Colors.orange,
            ),
          ),
        );
      },
    );
  }
}