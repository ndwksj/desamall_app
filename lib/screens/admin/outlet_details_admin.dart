import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Added for Image Upload

class OutletDetailsAdmin extends StatefulWidget {
  final Map<String, dynamic> outlet;
  final String docId; 

  OutletDetailsAdmin({required this.outlet, required this.docId});

  @override
  _OutletDetailsAdminState createState() => _OutletDetailsAdminState();
}

class _OutletDetailsAdminState extends State<OutletDetailsAdmin> {
  late TextEditingController nameController;
  late TextEditingController addressController;
  String? currentImageBase64; // To store selected/current image

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.outlet["name"]);
    addressController = TextEditingController(text: widget.outlet["address"]);
    currentImageBase64 = widget.outlet["image"]; // Load existing image
  }

  // Function to pick image from gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image != null) {
      final bytes = await File(image.path).readAsBytes();
      setState(() {
        currentImageBase64 = base64Encode(bytes);
      });
    }
  }

  void _deleteOutlet() async {
    try {
      await FirebaseFirestore.instance.collection('outlets').doc(widget.docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Outlet deleted successfully!"), backgroundColor: Color(0xFFD32F2F)),
        );
        Navigator.pop(context); 
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Remove Outlet?", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16)),
          content: const Text("This will permanently delete this location. This action cannot be undone.", style: TextStyle(color: Color(0xFF8A94A6), fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteOutlet();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), elevation: 0),
              child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _saveChanges() async {
    try {
      await FirebaseFirestore.instance.collection('outlets').doc(widget.docId).update({
        "name": nameController.text.trim(),
        "address": addressController.text.trim(),
        "image": currentImageBase64, // Saves the new Base64 or existing string
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Outlet updated successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA), 
      appBar: AppBar(
        title: const Text(
          "OUTLET CONFIGURATION", 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, fontSize: 15)
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFB71C1C)], // Unified Solid Crimson Red Gradient
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, size: 24),
            onPressed: _showDeleteConfirmation,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE UPLOAD SECTION
            const Text(
              "Outlet Showcase Image", 
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1F2A38), letterSpacing: 0.2)
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildDisplayImage(currentImageBase64)),
                      Container(color: Colors.black.withOpacity(0.25)), // Standard solid dim filter overlay
                      const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 36),
                            SizedBox(height: 8),
                            Text("Change Cover Photo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),

            // FORM SECTION
            const Text(
              "Operational Details", 
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1F2A38), letterSpacing: 0.2)
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: nameController,
              label: "Outlet Hub Name",
              icon: Icons.storefront_rounded,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: addressController,
              label: "Full Location Address",
              icon: Icons.map_outlined,
              maxLines: 3,
            ),
            
            const SizedBox(height: 40),

            // BUTTONS
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: const Color(0xFF8A94A6),
                    ),
                    child: const Text("DISCARD", style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F), // Matches true active red highlights
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0, // Flat clean execution design rule
                    ),
                    child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8A94A6), fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFFD32F2F), size: 18), // Set true red field accent icon
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(18),
        ),
      ),
    );
  }

  Widget _buildDisplayImage(String? path) {
    if (path == null || path.isEmpty) {
      return const Center(child: Icon(Icons.storefront_outlined, size: 40, color: Color(0xFFD2D7DB)));
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image));
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image));
    }
    try {
      return Image.memory(
        base64Decode(path.contains(',') ? path.split(',').last : path),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
      );
    } catch (e) {
      return const Icon(Icons.broken_image);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    super.dispose();
  }
}