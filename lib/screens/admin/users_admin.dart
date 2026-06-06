import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsersAdmin extends StatefulWidget {
  const UsersAdmin({Key? key}) : super(key: key);

  @override
  State<UsersAdmin> createState() => _UsersAdminState();
}

class _UsersAdminState extends State<UsersAdmin> {
  
  Future<void> _deleteUser(String docId) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Remove Admin?"),
            content: const Text("Are you sure you want to remove this admin?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Remove", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('admins').doc(docId).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Manage Branch Admins (UA)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('admins').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Database collection 'admins' is empty or unreachable."));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;

              // Safe fallbacks to match Firestore field types exactly
              String adminName = data['name'] ?? 'No Name';
              String adminEmail = data['email'] ?? 'No Email';
              String displayBranch = data['storename'] ?? data['branchAccess'] ?? 'Unassigned';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                  ),
                  title: Text(adminName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Branch: $displayBranch\nEmail: $adminEmail"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _deleteUser(docId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}