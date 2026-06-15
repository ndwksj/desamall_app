import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'dart:convert'; // 🔑 Added to decode raw image strings from the admin side
import '../cart.dart';
import '../favorites.dart';
import 'cart_page.dart'; // 🔄 Added to enable direct navigation to Cart view

class ProductDetailPage extends StatefulWidget {
  final String? id; 
  final String name;
  final String price; 
  final String image;
  final String outletId;
  final int stock; 

  const ProductDetailPage({
    Key? key, this.id, required this.name, required this.price, required this.image, required this.outletId, this.stock = 0, 
  }) : super(key: key);

  @override
  _ProductDetailPageState createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;

  double get parsedPrice {
    return double.tryParse(widget.price.replaceAll("RM", "").trim()) ?? 0.0;
  }

  // Helper method to safely handle base64, asset paths, and network links
  Widget _displayProductImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const Icon(Icons.image, size: 100, color: Colors.grey);
    }
    
    try {
      if (imageUrl.startsWith('http')) {
        return Image.network(imageUrl, fit: BoxFit.contain);
      }
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(imageUrl, fit: BoxFit.contain);
      }
      
      // Clean up base64 metadata if your admin app prefixes it
      String cleanBase64 = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
      
      return Image.memory(
        base64Decode(cleanBase64.trim()), 
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, size: 50, color: Colors.redAccent),
        ),
      );
    } catch (e) {
      return const Center(
        child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    // 1. Listen to Product data (Stock)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('products').doc(widget.id).snapshots(),
      builder: (context, productSnapshot) {
        
        int realStock = widget.stock;
        if (productSnapshot.hasData && productSnapshot.data!.exists) {
          var data = productSnapshot.data!.data() as Map<String, dynamic>;
          var s = data['stock'] ?? 0;
          realStock = (s is String) ? (int.tryParse(s) ?? 0) : (s as num).toInt();
        }

        int inBag = getItemQuantityInCart(widget.name, widget.outletId);
        bool isOutOfStock = realStock <= 0;
        bool bagIsFull = inBag >= realStock;
        bool isMaxReached = (inBag + _quantity) > realStock;

        // 2. Listen to User data (Real-time Reward Points)
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
          builder: (context, userSnapshot) {
            double currentUserPoints = 0.0;
            if (userSnapshot.hasData && userSnapshot.data!.exists) {
              var userData = userSnapshot.data!.data() as Map<String, dynamic>;
              currentUserPoints = (userData['reward_points'] ?? 0.0).toDouble();
            }

            // Calculate active dynamic total cart item count across this specific outlet storefront
            int totalCartCount = getCartCount(widget.outletId);

            // 3. Nested FutureBuilder to dynamically look up the true outlet branch name safely
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('outlets').doc(widget.outletId).get(),
              builder: (context, outletSnapshot) {
                String dynamicOutletName = "DesaMall Outlet"; // Reliable default fallback
                
                if (outletSnapshot.hasData && outletSnapshot.data!.exists) {
                  var outletData = outletSnapshot.data!.data() as Map<String, dynamic>;
                  dynamicOutletName = outletData['name'] ?? outletData['outletName'] ?? "DesaMall Outlet";
                }

                return Scaffold(
                  backgroundColor: Colors.grey[50],
                  appBar: AppBar(
                    title: const Text("Product Details", style: TextStyle(fontWeight: FontWeight.bold)),
                    centerTitle: true, backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      // 🛒 Live Dynamic Sync Bag Action Container Icon
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CartPage(
                                        outletId: widget.outletId,
                                        selectedOutlet: dynamicOutletName, // 🔑 FIXED: Passes true storefront name context
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shopping_bag_rounded, size: 18, color: Colors.black87),
                                ),
                              ),
                              if (totalCartCount > 0)
                                Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '$totalCartCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Your existing Rewards Points Indicator Card
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber[700]!)),
                            child: Row(children: [
                              Icon(Icons.stars, size: 14, color: Colors.amber[800]),
                              const SizedBox(width: 4),
                              Text("RM ${currentUserPoints.toStringAsFixed(2)}", style: TextStyle(color: Colors.amber[900], fontSize: 12, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ),
                      )
                    ],
                  ),
                  body: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: double.infinity, height: 350,
                        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
                        child: Hero(
                          tag: widget.name, 
                          child: Padding(
                            padding: const EdgeInsets.all(20.0), 
                            child: _displayProductImage(widget.image), // 🔑 UPDATED: Now supports both Base64 strings and assets safely
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(5)), child: const Text("OFFICIAL DESAMALL", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold))),
                            Text(isOutOfStock ? "SOLD OUT" : "Stock: $realStock", style: TextStyle(color: isOutOfStock ? Colors.red : Colors.grey[600], fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 12),
                          Text(widget.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text("RM ${parsedPrice.toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          const Divider(height: 40),
                          
                          Container(
                            width: double.infinity, 
                            padding: const EdgeInsets.all(16), 
                            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(15)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  // 🔑 Calculated at 0.0005 multiplier if total > 100
                                  "Earn ${( (parsedPrice * _quantity) >= 100.0 ? (parsedPrice * _quantity * 0.0005) : 0.0 ).toStringAsFixed(2)} points!", 
                                  style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "You will get reward points from this purchase to use for your next order if you spend more than RM100.",
                                  style: TextStyle(color: Colors.green[700], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text("High-quality product sourced directly from local technopreneurs.", style: TextStyle(color: Colors.grey[600], height: 1.5)),
                          const SizedBox(height: 100),
                        ]),
                      ),
                    ]),
                  ),
                  bottomNavigationBar: Container(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
                    decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]),
                    child: Row(children: [
                      IconButton(icon: Icon(isFavorite(widget.name) ? Icons.favorite : Icons.favorite_border, color: Colors.redAccent), onPressed: () => setState(() => isFavorite(widget.name) ? removeFavorite(widget.name) : addFavorite(widget.name, parsedPrice, widget.image))),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          IconButton(icon: const Icon(Icons.remove), onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null),
                          Text("$_quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.add), onPressed: (inBag + _quantity < realStock) ? () => setState(() => _quantity++) : null),
                        ]),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (isOutOfStock || bagIsFull || isMaxReached) ? Colors.grey : Colors.redAccent, 
                            padding: const EdgeInsets.symmetric(vertical: 18), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          onPressed: (isOutOfStock || bagIsFull || isMaxReached) ? null : () {
                            setState(() {
                              addItem(widget.name, parsedPrice, widget.image, widget.outletId, id: widget.id, stock: realStock, quantity: _quantity);
                              _quantity = 1; 
                            });
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Added to Bag")));
                          },
                          child: Text(
                            isOutOfStock ? "SOLD OUT" : ((bagIsFull || isMaxReached) ? "OUT OF STOCK" : "Add to Bag"), 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}