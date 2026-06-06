import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // 🔑 Native Flutter decoder (super lightweight, no installation needed!)
import 'product_detail_page.dart';

class CookingEssentialsPage extends StatelessWidget {
  final String outletId;

  const CookingEssentialsPage({Key? key, required this.outletId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Keperluan Memasak', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)), 
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HERO BANNER ---
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    child: Image.asset(
                      "assets/images/cooking_bg.png",
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.redAccent.withOpacity(0.1),
                        child: const Icon(Icons.restaurant_menu, size: 50, color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 25,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Kelengkapan Masakan", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                        "Keperluan Memasak",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- SECTION: ALL PRODUCTS ---
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
              child: Text("All Essentials", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('category', isEqualTo: 'Cooking essentials')
                  .where('outletId', arrayContains: outletId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(60.0),
                      child: Column(
                        children: [
                          Icon(Icons.shopping_basket_outlined, size: 70, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text("No cooking supplies here yet.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: docs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final String imagePath = item["imageUrl"]?.toString() ?? "";
                    final double price = (item["price"] is num) ? item["price"].toDouble() : double.tryParse(item["price"].toString()) ?? 0.0;

                    return _buildProductCard(context, doc.id, item, imagePath, price);
                  },
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, String docId, Map<String, dynamic> item, String imagePath, double price) {
    var rawStock = item["stock"] ?? 0;
    int parsedStock = (rawStock is String) ? (int.tryParse(rawStock) ?? 0) : (rawStock as num).toInt();

    // 🕒 FIX: Default to FALSE so old items without timestamp do not show the badge!
    bool isNewProduct = false; 
    
    if (item.containsKey('timestamp') && item['timestamp'] != null) {
      try {
        Timestamp docTimestamp = item['timestamp'];
        DateTime docDateTime = docTimestamp.toDate();
        // Item is marked new only if it was added within the last 48 hours
        isNewProduct = DateTime.now().difference(docDateTime).inHours <= 48;
      } catch (e) {
        isNewProduct = false;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => ProductDetailPage(
            id: docId, 
            name: item["name"] ?? "Product", 
            price: price.toString(), 
            image: imagePath, 
            outletId: outletId,
            stock: parsedStock, 
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                    child: _buildProductImage(imagePath),
                  ),
                  // ✨ Small "NEW" Product Badge overlay container
                  if (isNewProduct)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber, 
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                        ),
                        child: const Text(
                          "NEW", 
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item["name"] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("RM ${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14)),
                      const Icon(Icons.add_circle, color: Colors.redAccent, size: 22),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String path) {
    if (path.isEmpty) return const Icon(Icons.shopping_basket, size: 40, color: Colors.redAccent);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Builder(
        builder: (context) {
          try {
            if (path.startsWith('http')) {
              return Image.network(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image));
            }
            if (path.startsWith('assets/')) {
              return Image.asset(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported));
            }
            
            String cleanBase64 = path.contains(',') ? path.split(',').last : path;
            return Image.memory(
              base64Decode(cleanBase64.trim()),
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 35, color: Colors.grey),
            );
          } catch (e) {
            return const Icon(Icons.broken_image, size: 35, color: Colors.grey);
          }
        },
      ),
    );
  }
}