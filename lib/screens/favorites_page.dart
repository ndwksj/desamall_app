import 'package:flutter/material.dart';
import 'dart:convert'; // Added to safely decode Base64 image strings from your admin-side uploads
import '../favorites.dart';
import 'product_detail_page.dart';

class FavoritesPage extends StatefulWidget {
  final String outletId; 

  const FavoritesPage({Key? key, required this.outletId}) : super(key: key);

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  
  // Safe helper to process Network URLs, Base64 strings from admin, and typical Assets
  Widget _getSafeProductImage(String imageStr) {
    String cleanStr = imageStr.trim();
    
    if (cleanStr.startsWith('http://') || cleanStr.startsWith('https://')) {
      return Image.network(
        cleanStr,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40),
        ),
      );
    }
    
    if (cleanStr.length > 30 && !cleanStr.contains('/') && !cleanStr.contains('assets')) {
      try {
        if (cleanStr.contains(',')) {
          cleanStr = cleanStr.split(',').last;
        }

        String normalizedBase64 = cleanStr.replaceAll(RegExp(r'[\s\n\r]'), '');
        
        int mod = normalizedBase64.length % 4;
        if (mod > 0) {
          normalizedBase64 += '=' * (4 - mod);
        }

        return Image.memory(
          base64Decode(normalizedBase64),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 40),
          ),
        );
      } catch (_) {}
    }
    
    return Image.asset(
      cleanStr,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (c, e, s) => const Center(
        child: Icon(Icons.image_not_supported_rounded, color: Colors.grey, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: favorites.isEmpty
          ? Center(
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
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: favorites.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
              ),
              itemBuilder: (context, index) {
                final item = favorites[index];
                final String imgPath = item["image"] ?? "";

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailPage(
                          name: item["name"],
                          price: item["price"].toString(),
                          image: imgPath,
                          outletId: widget.outletId,
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
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                child: _getSafeProductImage(imgPath),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      removeFavorite(item["name"]);
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
                                item["name"],
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "RM ${item["price"].toStringAsFixed(2)}",
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
            ),
    );
  }
}