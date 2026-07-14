import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class ManageProductsPage extends StatefulWidget {
  final String? outletId;
  final VoidCallback? onBackToDashboard; 

  const ManageProductsPage({Key? key, this.outletId, this.onBackToDashboard}) : super(key: key);

  @override
  _ManageProductsPageState createState() => _ManageProductsPageState();
}

class _ManageProductsPageState extends State<ManageProductsPage> {
  String? selectedOutletId;
  String? selectedOutletName;

  // Matches products_admin.dart precisely
  final List<String> categories = [
    "Beverages", 
    "Cooking essentials", 
    "Food Supplements",
    "Gardening", 
    "Home care supplies", 
    "Nursery Page", 
    "Snacks"
  ];

  @override
  void initState() {
    super.initState();
    selectedOutletId = widget.outletId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)], // True Crimson Red Canvas Header
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    top: 15,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                      onPressed: () {
                        if (widget.onBackToDashboard != null) {
                          widget.onBackToDashboard!();
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                  const Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: Text(
                        "Stock MANAGER",
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 24, 
                          fontWeight: FontWeight.w900, 
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          _buildOutletDropdown(),

          Expanded(
            child: selectedOutletId == null
                ? _buildEmptyState("Please select an outlet location to view inventory")
                : _buildProductStream(),
          ),
        ],
      ),
      floatingActionButton: selectedOutletId != null 
        ? FloatingActionButton.extended(
            backgroundColor: const Color(0xFFD32F2F), // Solid Crimson Action Button
            elevation: 0, 
            onPressed: () => _showProductDialog(context),
            icon: const Icon(Icons.add_box_rounded, color: Colors.white),
            label: const Text("ADD PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          )
        : null,
    );
  }

  Widget _buildOutletDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('outlets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator(color: Color(0xFFD32F2F));
          var outlets = snapshot.data!.docs;
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "Store Location",
              labelStyle: const TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFFD32F2F)), // Crimson storefront icon
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE8ECEF), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5), // Crisp focal point color
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            value: selectedOutletId,
            items: outlets.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ""))).toList(),
            onChanged: (val) {
              setState(() {
                selectedOutletId = val;
                selectedOutletName = outlets.firstWhere((d) => d.id == val)['name'];
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildProductStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('outletId', arrayContains: selectedOutletId) 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
        }
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState("No products found for $selectedOutletName");

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            int stockCount = data['stock'] ?? 0; 

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2), 
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFFF8F9FA),
                    child: _displayImage(data['imageUrl'] ?? ""),
                  ),
                ),
                title: Text(
                  data['name'] ?? "No Name", 
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2A38), fontSize: 14),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text("Price: RM ${data['price']}", style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
                    const SizedBox(height: 2),
                    Text(
                      "In Stock: $stockCount",
                      style: TextStyle(
                        color: stockCount < 5 ? const Color(0xFFD32F2F) : Colors.green[700], // Correct matching alert red
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 26), 
                  onPressed: () => _showProductDialog(context, doc: docs[index]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProductDialog(BuildContext context, {DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final nameC = TextEditingController(text: data?['name'] ?? "");
    final priceC = TextEditingController(text: data?['price']?.toString() ?? "");
    final stockC = TextEditingController(text: (data?['stock'] ?? 0).toString());
    
    String selCat = (data != null && data.containsKey('category') && categories.contains(data['category'])) 
        ? data['category'] 
        : categories[0];
    
    bool showErrorBanner = false; 
    String errorMessage = ""; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            doc == null ? "Register New Product" : "Edit Catalog Inventory",
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showErrorBanner)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE), // Subtle crimson background banner tint
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage, 
                            style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                TextField(
                  controller: nameC,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Product Name", 
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true, 
                  value: selCat,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Category", 
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1F2A38))))).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selCat = val!;
                    });
                  },
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: priceC, 
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Price RM", 
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: stockC, 
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Current Stock", 
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F), // Matching Red action theme color
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              ),
              onPressed: () async {
                double enteredPrice = double.tryParse(priceC.text) ?? 0.0;
                int enteredStock = int.tryParse(stockC.text) ?? 0;

                if (enteredPrice < 0.0 && enteredStock < 0) {
                  setDialogState(() {
                    showErrorBanner = true;
                    errorMessage = "Price and Stock cannot be negative numbers!";
                  });
                  return;
                } else if (enteredPrice < 0.0) {
                  setDialogState(() {
                    showErrorBanner = true;
                    errorMessage = "Price cannot be a negative number!";
                  });
                  return;
                } else if (enteredStock < 0) {
                  setDialogState(() {
                    showErrorBanner = true;
                    errorMessage = "Stock cannot be a negative number!";
                  });
                  return;
                }

                List<dynamic> outletList = data?['outletId'] ?? [];
                if (selectedOutletId != null && !outletList.contains(selectedOutletId)) {
                  outletList.add(selectedOutletId);
                }

                final map = {
                  'name': nameC.text.trim(),
                  'price': enteredPrice,
                  'stock': enteredStock,
                  'category': selCat,
                  'outletId': outletList,
                };

                if (doc == null) {
                  await FirebaseFirestore.instance.collection('products').add(map);
                } else {
                  await doc.reference.update(map);
                }
                Navigator.pop(context);
              },
              child: Text(
                doc == null ? "Save" : "Update", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _displayImage(String url) {
    if (url.isEmpty) return const Icon(Icons.inventory_2_outlined, color: Color(0xFF8A94A6), size: 20);
    try {
      if (url.startsWith('assets/')) return Image.asset(url, fit: BoxFit.cover);
      return Image.memory(base64Decode(url.contains(',') ? url.split(',').last : url), fit: BoxFit.cover);
    } catch (e) { 
      return const Icon(Icons.broken_image_outlined, color: Color(0xFF8A94A6), size: 20); 
    }
  }

  Widget _buildEmptyState(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w600, fontSize: 13)),
    ),
  );
}