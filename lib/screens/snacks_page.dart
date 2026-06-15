import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // 🔑 Native Flutter decoder (super lightweight, no installation needed!)
import 'product_detail_page.dart';

class SnacksPage extends StatelessWidget {
  final String outletId;

  const SnacksPage({Key? key, required this.outletId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Makanan Ringan', 
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
            Stack(
              children: [
                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    child: Image.asset(
                      "assets/images/snacks_bg.png",
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.redAccent.withOpacity(0.1),
                        child: const Icon(Icons.fastfood, size: 50, color: Colors.redAccent),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(
                    "Makanan Ringan",
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('category', isEqualTo: 'Snacks')
                  .where('outletId', arrayContains: outletId) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(50.0),
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(60.0),
                      child: Column(
                        children: [
                          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text("No snacks available at this outlet.", 
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    crossAxisSpacing: 15, 
                    mainAxisSpacing: 15, 
                    childAspectRatio: 0.72,
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final String imagePath = item["imageUrl"]?.toString() ?? "";
                    final double price = (item["price"] is num) ? item["price"].toDouble() : double.tryParse(item["price"].toString()) ?? 0.0;

                    // 🎯 FIX: Parse stock safely
                    var rawStock = item["stock"] ?? 0;
                    int parsedStock = (rawStock is String) ? (int.tryParse(rawStock) ?? 0) : (rawStock as num).toInt();

                    // 🕒 Smart "NEW" calculation tag logic:
                    // Defaults to false so old products do not show the badge unless added within 48 hours.
                    bool isNewProduct = false; 
                    if (item.containsKey('timestamp') && item['timestamp'] != null) {
                      try {
                        Timestamp docTimestamp = item['timestamp'];
                        DateTime docDateTime = docTimestamp.toDate();
                        isNewProduct = DateTime.now().difference(docDateTime).inHours <= 48;
                      } catch (e) {
                        isNewProduct = false;
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => ProductDetailPage(
                            id: doc.id, // 🎯 FIX: Passing ID
                            name: item["name"] ?? "Snack",
                            price: price.toString(),
                            image: imagePath,
                            outletId: outletId,
                            stock: parsedStock, // 🎯 FIX: Passing Stock
                          ),
                        ));
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
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
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    child: _buildProductImage(imagePath),
                                  ),
                                  // ✨ Small "NEW" Product Badge Overlay Container
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
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item["name"] ?? "", 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), 
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "RM ${price.toStringAsFixed(2)}", 
                                        style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 15),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.add, size: 16, color: Colors.redAccent),
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String path) {
    if (path.isEmpty) return const Icon(Icons.cookie, size: 50, color: Colors.redAccent);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Builder(
        builder: (context) {
          try {
            if (path.startsWith('http')) {
              return Image.network(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.redAccent));
            }
            if (path.startsWith('assets/')) {
              return Image.asset(path, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, color: Colors.redAccent));
            }
            
            // Native lightweight parser processes administrative uploaded Base64 string packages smoothly
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