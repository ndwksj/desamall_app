import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:convert'; // 🔑 Native Flutter decoder (super lightweight, no installation needed!)
import '../favorites.dart';
import 'product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  final String outletId; 

  const FavoritesPage({Key? key, required this.outletId}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  
  @override
  Widget build(BuildContext context) {
    // Collect all unique item names from your local wishlist array
    List<String> favoriteNames = favorites.map((item) => (item["name"] ?? "").toString()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("My Wishlist", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        // 🎯 FIX: Navigates explicitly to your HomeScreen named route and clears the login/outlet stack!
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context, 
              '/home', 
              (route) => false, // This wipes out the route history so back button behaves perfectly
            );
          },
        ),
      ),
      body: favoriteNames.isEmpty
          ? _buildEmptyState()
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('name', whereIn: favoriteNames)
                  .where('outletId', arrayContains: widget.outletId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading wishlist products"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    
                    final String imagePath = item["imageUrl"]?.toString() ?? item["image"]?.toString() ?? "";
                    final double price = (item["price"] is num) ? item["price"].toDouble() : double.tryParse(item["price"].toString()) ?? 0.0;
                    
                    var rawStock = item["stock"] ?? 0;
                    int parsedStock = (rawStock is String) 
                        ? (int.tryParse(rawStock) ?? 0) 
                        : (rawStock as num).toInt();

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailPage(
                              id: doc.id,
                              name: item["name"] ?? "Unknown",
                              price: price.toString(),
                              image: imagePath.isEmpty ? "assets/images/air 1.png" : imagePath,
                              outletId: widget.outletId,
                              stock: parsedStock, 
                            ),
                          ),
                        ).then((value) {
                          setState(() {});
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // --- IMAGE SECTION WITH REMOVE BUTTON ---
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
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          removeFavorite(item["name"] ?? "");
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Removed from favorites"),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 20),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // --- TEXT DETAILS ---
                            Padding(
                              padding: const EdgeInsets.all(12.0),
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
                                  Text(
                                    "RM ${price.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.redAccent, 
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // --- STYLISH EMPTY STATE ---
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_rounded, size: 100, color: Colors.redAccent.withOpacity(0.2)),
          ),
          const SizedBox(height: 24),
          const Text(
            "Nothing here yet!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            "Tap the heart on products you love\nto see them here.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(String path) {
    if (path.isEmpty) {
      return const Icon(Icons.local_drink_rounded, size: 40, color: Colors.redAccent);
    }
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