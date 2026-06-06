import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({Key? key}) : super(key: key);

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🛠️ FUNCTION: Delete Admin
  Future<void> _deleteUser(String docId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Remove Admin Account?", 
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16)
        ),
        content: const Text(
          "This action cannot be undone and terminates their workspace entry privileges completely.", 
          style: TextStyle(color: Color(0xFF8A94A6), fontSize: 14)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0
            ),
            onPressed: () async {
              await _firestore.collection('admins').doc(docId).delete();
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Admin account deleted successfully"), backgroundColor: Colors.black87),
                );
              }
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // 🛠️ FUNCTION: Edit Admin Account details
  void _editUser(String docId, Map<String, dynamic> userData) {
    TextEditingController nameController = TextEditingController(text: userData['name']);
    TextEditingController emailController = TextEditingController(text: userData['email']);
    TextEditingController branchAccessController = TextEditingController(text: (userData['branchAccess'] ?? userData['storename'] ?? 'all').toString());
    TextEditingController storeNameController = TextEditingController(text: userData['storename']);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Edit Admin Profile", 
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16)
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController, 
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: "Admin Name", labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)))
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController, 
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: "Email Address", labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)))
              ),
              const SizedBox(height: 12),
              TextField(
                controller: branchAccessController, 
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: "Branch Access Identifier", labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)))
              ),
              const SizedBox(height: 12),
              TextField(
                controller: storeNameController, 
                style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                decoration: const InputDecoration(labelText: "Store Label Name", labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6)))
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            onPressed: () async {
              await _firestore.collection('admins').doc(docId).update({
                'name': nameController.text.trim(),
                'email': emailController.text.trim(),
                'branchAccess': branchAccessController.text.trim(),
                'storename': storeNameController.text.trim(),
              });
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Admin profile updated successfully"), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA), // Standard enterprise canvas background
      appBar: AppBar(
        title: const Text(
          "TEAM ADMINISTRATORS", 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, fontSize: 15)
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFB71C1C)], // True Red Gradient
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('admins').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Operations Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w800),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No registered branch admins found.", 
                style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w600, fontSize: 13)
              )
            );
          }

          final adminDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: adminDocs.length,
            itemBuilder: (context, index) {
              var userData = adminDocs[index].data() as Map<String, dynamic>;
              String docId = adminDocs[index].id;

              String adminName = userData['name'] ?? 'Unnamed Admin';
              String adminEmail = userData['email'] ?? 'No Email';
              String branchTag = (userData['branchAccess'] ?? 'all').toString().trim();
              String storeNameLabel = userData['storename'] ?? 'Global Hub / Unassigned';
              
              bool isGlobalAdmin = (branchTag.toLowerCase() == 'all');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Identity Shield Avatar Badge
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isGlobalAdmin ? const Color(0xFFFFEBEE) : const Color(0xFFF0F4F8),
                          shape: BoxShape.circle
                        ),
                        child: Icon(
                          isGlobalAdmin ? Icons.admin_panel_settings : Icons.store_mall_directory_rounded, 
                          color: isGlobalAdmin ? const Color(0xFFD32F2F) : const Color(0xFF4A5568), 
                          size: 22
                        )
                      ),
                      const SizedBox(width: 14),
                      
                      // Account Meta details 
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              adminName, 
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F2A38), fontSize: 14)
                            ),
                            const SizedBox(height: 2),
                            Text(
                              adminEmail, 
                              style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 12, fontWeight: FontWeight.w500)
                            ),
                            const SizedBox(height: 10),
                            
                            // Custom Pill Badge Layout 
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isGlobalAdmin ? const Color(0xFFD32F2F).withOpacity(0.08) : const Color(0xFFF1F3F5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Access: ${branchTag.toUpperCase()}",
                                    style: TextStyle(
                                      color: isGlobalAdmin ? const Color(0xFFB71C1C) : const Color(0xFF4A5568),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F9FA),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE9ECEF), width: 1)
                                  ),
                                  child: Text(
                                    storeNameLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF616E7C),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Action Section Items
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 24),
                            onPressed: () => _editUser(docId, userData),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(6),
                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 20),
                            onPressed: () => _deleteUser(docId),
                          ),
                        ],
                      )
                    ],
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