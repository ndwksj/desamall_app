import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:convert'; // 🔑 Native Flutter decoder (super lightweight, no installation needed!)
import 'product_detail_page.dart';

class GardeningPage extends StatefulWidget {
  final String outletId;

  const GardeningPage({Key? key, required this.outletId}) : super(key: key);

  @override
  State<GardeningPage> createState() => _GardeningPageState();
}

class _GardeningPageState extends State<GardeningPage> {
  // 🔑 Filter State Tracking Variables
  String? selectedPrice;
  String? selectedSort;
  String? selectedColor;

  double _forceDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _forceInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return (double.tryParse(value) ?? 0.0).toInt();
    return 0;
  }

  // 🔑 Reuses your clean bottom sheet UI logic but applies parameters locally to this page
  void _openFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20.0),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Filter Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
          ]),
          _buildFilterSection("Price Range", ["RM 0 - RM 10", "RM 10 - RM 50", "RM 50 - RM 100", "Above RM 100"], selectedPrice, (val) => setState(() => selectedPrice = val)),
          _buildFilterSection("Sort By", ["Popular", "Least Popular"], selectedSort, (val) => setState(() => selectedSort = val)),
          _buildFilterSection("By Colour", ["Blue", "Pink", "Green", "White", "Black"], selectedColor, (val) => setState(() => selectedColor = val)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), side: const BorderSide(color: Colors.grey)),
                  onPressed: () {
                    setState(() {
                      selectedPrice = null;
                      selectedSort = null;
                      selectedColor = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text("CLEAR", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("APPLY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, String? selected, Function(String) onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: options.map((opt) => Padding(padding: const EdgeInsets.only(right: 8.0), child: ChoiceChip(label: Text(opt), selected: selected == opt, onSelected: (bool s) => onSelect(opt), selectedColor: Colors.redAccent.withOpacity(0.2), checkmarkColor: Colors.redAccent))).toList())),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Kelengkapan Berkebun', 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)), 
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          // 🔑 Filter Button Action Added onto your Category Screen Navigation Frame
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white), 
            onPressed: () => _openFilter(context)
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PREMIUM HERO BANNER ---
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
                      "assets/images/gardening_bg.png",
                      fit: BoxFit.cover, 
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.redAccent.withOpacity(0.1),
                        child: const Icon(Icons.yard_outlined, size: 50, color: Colors.redAccent),
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
                      Text("Keperluan Luar Rumah", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                        "Kelengkapan Berkebun",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // --- SECTION: GRID VIEW ---
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 20, 10),
              child: Text("All Supplies", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('category', isEqualTo: 'Gardening') 
                  .where('outletId', arrayContains: widget.outletId) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  ));
                }

                // 🔑 Engine matching parsing parameters dynamically out of Firestore matching criteria logic
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final color = data['color']?.toString().toLowerCase() ?? "";
                  double currentPrice = _forceDouble(data['price']);

                  bool matchesPrice = true;
                  if (selectedPrice != null) {
                    if (selectedPrice == "RM 0 - RM 10") matchesPrice = currentPrice <= 10;
                    else if (selectedPrice == "RM 10 - RM 50") matchesPrice = currentPrice > 10 && currentPrice <= 50;
                    else if (selectedPrice == "RM 50 - RM 100") matchesPrice = currentPrice > 50 && currentPrice <= 100;
                    else if (selectedPrice == "Above RM 100") matchesPrice = currentPrice > 100;
                  }
                  
                  bool matchesColor = selectedColor == null || color == selectedColor!.toLowerCase();

                  return matchesPrice && matchesColor;
                }).toList();

                // 🔑 Re-order array items accurately based on sales metrics sorting selection values
                docs.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;

                  int metricA = _forceInt(dataA['salesCount'] ?? dataA['revenue']);
                  int metricB = _forceInt(dataB['salesCount'] ?? dataB['revenue']);

                  if (selectedSort == "Least Popular") {
                    int comp = metricA.compareTo(metricB);
                    if (comp != 0) return comp;
                  } else if (selectedSort == "Popular") {
                    int comp = metricB.compareTo(metricA);
                    if (comp != 0) return comp;
                  }

                  double priceA = _forceDouble(dataA['price']);
                  double priceB = _forceDouble(dataB['price']);
                  return priceA.compareTo(priceB);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(60.0),
                      child: Column(
                        children: [
                          Icon(Icons.filter_vintage_outlined, size: 70, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          const Text("No gardening items match your filter choices.", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }

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

  // REUSABLE GRID CARD
  Widget _buildProductCard(BuildContext context, String docId, Map<String, dynamic> item, String imagePath, double price) {
    var rawStock = item["stock"] ?? 0;
    int parsedStock = (rawStock is String) ? (int.tryParse(rawStock) ?? 0) : (rawStock as num).toInt();

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
            id: docId, 
            name: item["name"] ?? "Item",
            price: price.toString(),
            image: imagePath,
            outletId: widget.outletId,
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
                      const Icon(Icons.add_circle_outline, color: Colors.redAccent, size: 22),
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
    if (path.isEmpty) return const Icon(Icons.park_outlined, size: 40, color: Colors.redAccent);
    
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