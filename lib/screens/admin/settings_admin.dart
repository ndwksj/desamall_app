import 'dart:io';
import 'dart:convert'; // Needed for Base64
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class SettingsAdminPage extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;

  void _contactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Technical Support"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("For system assistance, contact the developer:"),
            SizedBox(height: 15),
            Text("support@desamall.com", 
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }
          
          var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String? base64Image = data['storeLogo']; // Get Base64 String

          return SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 250, 
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.redAccent, Color(0xFFB71C1C)],
                        ),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
                      ),
                      child: SafeArea(
                        child: Stack(
                          children: [
                            Positioned(
                              left: 10,
                              top: 5,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const Align(
                              alignment: Alignment.topCenter,
                              child: Padding(
                                padding: EdgeInsets.only(top: 15),
                                child: Text("System Settings",
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 140, 
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))
                          ],
                        ),
                        child: Column(
                          children: [
                            // SHOW BASE64 LOGO OR DEFAULT ICON
                            CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.redAccent,
                              backgroundImage: base64Image != null 
                                  ? MemoryImage(base64Decode(base64Image)) 
                                  : null,
                              child: base64Image == null 
                                  ? const Icon(Icons.storefront_rounded, size: 40, color: Colors.white) 
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              data['storeName'] ?? "DesaMall HQ", 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              "Outlet Business Profile Context", 
                              style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 80),

                _buildSectionHeader("Branch Management"),
                _buildModernTile(
                  icon: Icons.storefront_outlined,
                  title: "Store Configuration",
                  subtitle: "Edit outlet logo, name, and contact details",
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StoreConfigPage(currentData: data))),
                ),
                _buildModernTile(
                  icon: Icons.help_outline_rounded,
                  title: "Technical Support",
                  subtitle: "Contact system developer",
                  onTap: () => _contactSupport(context),
                ),

                const SizedBox(height: 30),
                _buildLogoutButton(context),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title.toUpperCase(), style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildModernTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                child: Icon(icon, color: Colors.redAccent, size: 22),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: InkWell(
        onTap: () async {
          await FirebaseAuth.instance.signOut();
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              SizedBox(width: 10),
              Text("Logout Admin Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- STORE CONFIGURATION PAGE (WITH BASE64 LOGIC) ---
class StoreConfigPage extends StatefulWidget {
  final Map<String, dynamic> currentData;
  const StoreConfigPage({super.key, required this.currentData});
  @override
  _StoreConfigPageState createState() => _StoreConfigPageState();
}

class _StoreConfigPageState extends State<StoreConfigPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController branchController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? _base64Image; // Stores the string
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.currentData['storeName'] ?? "";
    branchController.text = widget.currentData['branchLocation'] ?? "";
    phoneController.text = widget.currentData['phoneNumber'] ?? "";
    _base64Image = widget.currentData['storeLogo'];
  }

  Future<void> _pickAndConvertImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400, // Resize to keep Base64 string short
      imageQuality: 70, 
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes); // Convert to String
      });
    }
  }

  @override
  Widget build(BuildContextcontext) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Store Configuration"), 
        backgroundColor: Colors.redAccent, 
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickAndConvertImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage: _base64Image != null ? MemoryImage(base64Decode(_base64Image!)) : null,
                child: _base64Image == null ? const Icon(Icons.add_a_photo, color: Colors.redAccent) : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Store Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: branchController, decoration: const InputDecoration(labelText: "Branch Location", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 50)),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('admins').doc(FirebaseAuth.instance.currentUser?.uid).set({
                  'storeName': nameController.text.trim(),
                  'branchLocation': branchController.text.trim(),
                  'phoneNumber': phoneController.text.trim(),
                  'storeLogo': _base64Image, // Saves string to Firestore
                }, SetOptions(merge: true));
                Navigator.pop(context);
              },
              child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}