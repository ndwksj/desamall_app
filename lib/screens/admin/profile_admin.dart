import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; 

// 🎯 Make sure these paths match your project structure
import 'package:desamall_app/screens/admin/change_password_screen.dart';
import 'package:desamall_app/screens/admin/sales_report_page.dart';
import 'package:desamall_app/screens/admin/settings_admin.dart'; 

class ProfileAdmin extends StatefulWidget {
  @override
  _ProfileAdminState createState() => _ProfileAdminState();
}

class _ProfileAdminState extends State<ProfileAdmin> {
  final User? user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  void _showEditProfileDialog(String currentName, String? currentBase64) {
    TextEditingController nameEditController = TextEditingController(text: currentName);
    String? newBase64 = currentBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 25, right: 25, top: 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 20),
              const Text("Update Personal Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              GestureDetector(
                onTap: () async {
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 400, imageQuality: 70);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setModalState(() => newBase64 = base64Encode(bytes));
                  }
                },
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: newBase64 != null ? MemoryImage(base64Decode(newBase64!)) : null,
                  child: newBase64 == null ? const Icon(Icons.add_a_photo, color: Colors.redAccent, size: 30) : null,
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: nameEditController,
                decoration: InputDecoration(
                  labelText: "Personal Admin Name",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('admins').doc(user?.uid).update({
                      'name': nameEditController.text.trim(),
                      'profilePicture': newBase64,
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("UPDATE PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('admins').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String name = "Admin Dalilah"; 
          String email = user?.email ?? "dalilahadmin@desamall.com";
          String? profileBase64;
          String branchAccess = 'all'; // Default fallback if field doesn't exist yet

          if (snapshot.hasData && snapshot.data!.exists) {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Admin Dalilah";
            profileBase64 = data['profilePicture'];
            branchAccess = data['branchAccess'] ?? 'all'; // Successfully fetches the admin's assigned store document ID
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 330,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: 220,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.redAccent, Color(0xFFB71C1C)]),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
                          ),
                          child: const Center(child: Text("Admin Console", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                        ),
                      ),
                      Positioned(
                        top: 150,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundImage: profileBase64 != null ? MemoryImage(base64Decode(profileBase64)) : null,
                              child: profileBase64 == null ? const Icon(Icons.person, size: 50, color: Colors.redAccent) : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.edit_note, size: 20), onPressed: () => _showEditProfileDialog(name, profileBase64)),
                              ],
                            ),
                            Text(email, style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _buildAdminTile(
                  icon: Icons.security,
                  title: "Security Settings",
                  subtitle: "Change password",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen())),
                ),
                
                // 📊 PASSING SECURITY ACCESS STRING TO SALES REPORT
                _buildAdminTile(
                  icon: Icons.bar_chart,
                  title: "Sales Report",
                  subtitle: "View analytics",
                  onTap: () => Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => SalesReportPage(branchAccess: branchAccess),
                    ),
                  ),
                ),
                
                // 🎯 FIXED NAME HERE: SettingsAdminPage
                _buildAdminTile(
                  icon: Icons.settings,
                  title: "System Settings",
                  subtitle: "App configuration",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsAdminPage())),
                ),

                const SizedBox(height: 30),
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text("Logout Admin", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdminTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.redAccent),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 12))])),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}