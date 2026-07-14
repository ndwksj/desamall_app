import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart'; 
import 'homecare_page.dart';
import 'gardening_page.dart';
import 'nursery_page.dart';
import 'beverages_page.dart';
import 'cooking_essentials_page.dart';
import 'snacks_page.dart';
import 'food_supplement_page.dart';
import 'product_detail_page.dart';
import 'cart_page.dart'; 
import '../cart.dart';   
import 'dart:convert'; 

class CategoriesPage extends StatelessWidget {
  final String outletId;

  const CategoriesPage({Key? key, required this.outletId}) : super(key: key);

  Future<String> _fetchOutletName() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('outlets').doc(outletId).get();
    return doc.exists ? doc['name'] : "DesaMall Outlet";
  }

  void _openFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => FilterBottomSheet(outletId: outletId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> sections = {
      "Makanan": [
        {"title": "Makanan Ringan", "image": "assets/images/snacks_bg.png", "page": SnacksPage(outletId: outletId)},
        {"title": "Keperluan Memasak", "image": "assets/images/cooking_bg.png", "page": CookingEssentialsPage(outletId: outletId)},
      ],
      "Minuman": [
        {"title": "Minuman", "image": "assets/images/beverages_bg.png", "page": BeveragesPage(outletId: outletId)},
      ],
      "Kesihatan": [
        {"title": "Suplemen Makanan", "image": "assets/images/supplement_bg.png", "page": FoodSupplementPage(outletId: outletId)},
      ],
      "Rumah & Lain-lain": [
        {"title": "Kelengkapan Penjagaan Rumah", "image": "assets/images/homecare_bg.png", "page": HomeCarePage(outletId: outletId)},
        {"title": "Kelengkapan Berkebun", "image": "assets/images/gardening_bg.png", "page": GardeningPage(outletId: outletId)},
        {"title": "Keperluan Bayi", "image": "assets/images/nursery_background.png", "page": NurseryPage(outletId: outletId)},
      ],
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Kategori", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
          onPressed: () async {
            String outletName = await _fetchOutletName();
            if (context.mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(outletId: outletId),
                  settings: RouteSettings(arguments: {'id': outletId, 'name': outletName}),
                ),
                (route) => false,
              );
            }
          },
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
        actions: [
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.white), onPressed: () => _openFilter(context)),
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () => showSearch(context: context, delegate: ProductSearchDelegate(outletId: outletId))),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                onPressed: () async {
                  String name = await _fetchOutletName();
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CartPage(outletId: outletId, selectedOutlet: name)));
                  }
                },
              ),
              if (getCartCount(outletId) > 0)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.redAccent, width: 1)),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('${getCartCount(outletId)}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          String sectionTitle = sections.keys.elementAt(index);
          List<Map<String, dynamic>> categoryList = sections[sectionTitle]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 25, bottom: 15, left: 5),
                child: Row(children: [
                  Container(width: 5, height: 20, decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(width: 10),
                  Text(sectionTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                ]),
              ),
              ...categoryList.map((category) => GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => category["page"])),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(children: [
                    ClipRRect(borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)), child: Image.asset(category["image"], width: 120, height: 90, fit: BoxFit.cover)),
                    const SizedBox(width: 16),
                    Expanded(child: Text(category["title"], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
                    const Icon(Icons.chevron_right_rounded, color: Colors.redAccent),
                    const SizedBox(width: 15),
                  ]),
                ),
              )).toList(),
            ],
          );
        },
      ),
    );
  }
}

class FilterBottomSheet extends StatefulWidget {
  final String outletId;
  const FilterBottomSheet({Key? key, required this.outletId}) : super(key: key);
  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? selectedPrice;
  String? selectedSort;
  String? selectedColor;
  
  final List<String> priceRanges = ["RM 0 - RM 10", "RM 10 - RM 50", "RM 50 - RM 100", "Above RM 100"];
  final List<String> sortOptions = ["Popular", "Least Popular"];
  final List<String> colors = ["Blue", "Pink", "Green", "White", "Black"];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Filter Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
        ]),
        _buildFilterSection("Price Range", priceRanges, selectedPrice, (val) => setState(() => selectedPrice = val)),
        _buildFilterSection("Sort By", sortOptions, selectedSort, (val) => setState(() => selectedSort = val)),
        _buildFilterSection("By Colour", colors, selectedColor, (val) => setState(() => selectedColor = val)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
            onPressed: () {
              Navigator.pop(context);
              showSearch(context: context, delegate: ProductSearchDelegate(outletId: widget.outletId, priceFilter: selectedPrice, sortFilter: selectedSort, colorFilter: selectedColor));
            },
            child: const Text("APPLY FILTERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, String? selected, Function(String) onSelect) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54))),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: options.map((opt) => Padding(padding: const EdgeInsets.only(right: 8.0), child: ChoiceChip(label: Text(opt), selected: selected == opt, onSelected: (bool s) => onSelect(opt), selectedColor: Colors.redAccent.withOpacity(0.2), checkmarkColor: Colors.redAccent))).toList())),
    ]);
  }
}

class ProductSearchDelegate extends SearchDelegate {
  final String outletId;
  final String? priceFilter;
  final String? sortFilter;
  final String? colorFilter;

  ProductSearchDelegate({required this.outletId, this.priceFilter, this.sortFilter, this.colorFilter});

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

  // Helper image layout visual engine to cleanly load images on your results grid
  Widget _displayGridProductImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const Center(child: Icon(Icons.shopping_bag_outlined, color: Colors.redAccent, size: 40));
    }
    try {
      if (imageUrl.startsWith('http')) {
        return Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
      if (imageUrl.startsWith('assets/')) {
        return Image.asset(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
      }
      String cleanBase64 = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
      return Image.memory(
        base64Decode(cleanBase64.trim()), 
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.shopping_bag_outlined, color: Colors.redAccent, size: 40)),
      );
    } catch (e) {
      return const Center(child: Icon(Icons.shopping_bag_outlined, color: Colors.redAccent, size: 40));
    }
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = "")];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();
  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    Query queryRef = FirebaseFirestore.instance.collection('products').where('outletId', arrayContains: outletId);
    
    return StreamBuilder<QuerySnapshot>(
      stream: queryRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        
        var results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name']?.toString().toLowerCase() ?? "";
          final color = data['color']?.toString().toLowerCase() ?? "";
          
          double currentPrice = _forceDouble(data['price']);
          bool matchesSearch = query.isEmpty || name.contains(query.toLowerCase());

          bool matchesPrice = true;
          if (priceFilter != null) {
            if (priceFilter == "RM 0 - RM 10") matchesPrice = currentPrice <= 10;
            else if (priceFilter == "RM 10 - RM 50") matchesPrice = currentPrice > 10 && currentPrice <= 50;
            else if (priceFilter == "RM 50 - RM 100") matchesPrice = currentPrice > 50 && currentPrice <= 100;
            else if (priceFilter == "Above RM 100") matchesPrice = currentPrice > 100;
          }
          bool matchesColor = colorFilter == null || color == colorFilter!.toLowerCase();

          return matchesSearch && matchesPrice && matchesColor;
        }).toList();

        // 🔑 FIXED POPULARITY FILTER COUPLING:
        // Prioritizes popular sorting directly when selected, making items rearrange accurately
        results.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          // Read transaction tracking numbers ('revenue' or 'salesCount')
          int metricA = _forceInt(dataA['salesCount'] ?? dataA['revenue']);
          int metricB = _forceInt(dataB['salesCount'] ?? dataB['revenue']);

          if (sortFilter == "Least Popular") {
            int comp = metricA.compareTo(metricB);
            if (comp != 0) return comp;
          } else if (sortFilter == "Popular") {
            int comp = metricB.compareTo(metricA);
            if (comp != 0) return comp;
          }

          //  sort by price
          double priceA = _forceDouble(dataA['price']);
          double priceB = _forceDouble(dataB['price']);
          return priceA.compareTo(priceB);
        });

        final topResults = results.take(10).toList();

        if (topResults.isEmpty) return const Center(child: Text("No items match your search.", style: TextStyle(color: Colors.grey)));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            childAspectRatio: 0.70, 
            crossAxisSpacing: 12, 
            mainAxisSpacing: 12
          ),
          itemCount: topResults.length,
          itemBuilder: (context, index) {
            final doc = topResults[index];
            final data = doc.data() as Map<String, dynamic>;
            
            // Look up alternative variant image fields securely
            String resolvedImage = data['imageUrl'] ?? data['image'] ?? '';

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(
                  id: doc.id, 
                  name: data['name'] ?? '', 
                  price: data['price'].toString(), 
                  image: resolvedImage, 
                  outletId: outletId, 
                  stock: _forceInt(data['stock']) 
                )));
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.05),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: _displayGridProductImage(resolvedImage), // 🔑 UPDATED: Load base64/network items safely
                            ),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(8)),
                              child: Text("RM ${_forceDouble(data['price']).toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
                          Text(data['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(data['category'] ?? 'Product', style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
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
    );
  }
}