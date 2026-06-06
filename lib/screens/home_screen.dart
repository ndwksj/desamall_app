import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // 🔑 Native Flutter decoder from nursery_page.dart
import '../models/product.dart';
import 'categories_page.dart';
import 'cart_page.dart';
import 'favorites_page.dart';
import 'profile_page.dart';
import 'product_detail_page.dart';
import '../cart.dart';
import '../favorites.dart';

// Category imports
import 'beverages_page.dart';
import 'cooking_essentials_page.dart';
import 'gardening_page.dart';
import 'homecare_page.dart';
import 'nursery_page.dart';
import 'snacks_page.dart';
import 'food_supplement_page.dart';

class HomeScreen extends StatefulWidget {
  final String? outletId;

  const HomeScreen({Key? key, this.outletId}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Map<String, String>> categories = [
    {"name": "Minuman", "image": "assets/categories/beverages_bg.png"},
    {"name": "Keperluan Memasak", "image": "assets/categories/cooking_bg.png"},
    {"name": "Kelengkapan Berkebun", "image": "assets/categories/gardening_bg.png"},
    {"name": "Kelengkapan Penjagaan Rumah", "image": "assets/categories/homecare_bg.png"},
    {"name": "Keperluan Bayi", "image": "assets/categories/nursery_background.png"},
    {"name": "Snek / Makanan Ringan", "image": "assets/categories/snacks_bg.png"},
    {"name": "Suplemen Makanan", "image": "assets/categories/supplement_bg.png"},
  ];

  // 🔑 Helper method implementing the exact nursery_page image rendering engine
  Widget _buildProductImage(String path) {
    if (path.isEmpty) return const Icon(Icons.image, size: 35, color: Colors.grey);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Builder(
        builder: (context) {
          try {
            if (path.startsWith('http')) {
              return Image.network(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (c, e, s) => const Icon(Icons.broken_image));
            }
            if (path.startsWith('assets/')) {
              return Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported));
            }
            
            String cleanBase64 = path.contains(',') ? path.split(',').last : path;
            return Image.memory(
              base64Decode(cleanBase64.trim()),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 35, color: Colors.grey),
            );
          } catch (e) {
            return const Icon(Icons.broken_image, size: 35, color: Colors.grey);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String selectedOutletId = widget.outletId ?? args?['id'] ?? "";
    final String selectedOutletName = args?['name'] ?? "DesaMall Outlet";

    int cartCount = getCartCount(selectedOutletId);
    int favCount = getFavoritesCount();

    final List<Widget> _pages = [
      _buildHomeContent(selectedOutletName, selectedOutletId),
      selectedOutletId.isEmpty 
          ? _buildGlobalOnboardingPlaceholder() 
          : CategoriesPage(outletId: selectedOutletId),
      selectedOutletId.isEmpty 
          ? _buildGlobalOnboardingPlaceholder() 
          : CartPage(selectedOutlet: selectedOutletName, outletId: selectedOutletId),
      selectedOutletId.isEmpty 
          ? _buildGlobalOnboardingPlaceholder() 
          : FavoritesPage(outletId: selectedOutletId),
      ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.redAccent,
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: "Shop"),
            BottomNavigationBarItem(icon: _buildBadgeIcon(Icons.shopping_bag_rounded, cartCount), label: "Bag"),
            BottomNavigationBarItem(icon: _buildBadgeIcon(Icons.favorite_rounded, favCount), label: "Favorites"),
            const BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profile"),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(String outletName, String outletId) {
    if (outletId.isEmpty) {
      return _buildGlobalOnboardingPlaceholder();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Welcome to", style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(outletName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 26),
                            onPressed: () {
                              showSearch(
                                context: context,
                                delegate: ProductSearchDelegate(outletId: outletId),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/outlets'),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.storefront, color: Colors.redAccent),
                              SizedBox(width: 10),
                              Text("Switch Branch / Outlet", style: TextStyle(color: Colors.grey, fontSize: 14)),
                              Spacer(),
                              Icon(Icons.swap_horiz, color: Colors.redAccent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Categories", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: () => setState(() => _selectedIndex = 1),
                    child: const Text("See All", style: TextStyle(color: Colors.redAccent))
                ),
              ],
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return GestureDetector(
                  onTap: () => _navigateToCategory(category["name"]!, outletId),
                  child: Container(
                    width: 85,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                          ),
                          child: Image.asset(category["image"]!, height: 35, errorBuilder: (c,e,s) => const Icon(Icons.category, color: Colors.redAccent)),
                        ),
                        const SizedBox(height: 8),
                        Text(category["name"]!.split(' ')[0],
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 25),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Icon(Icons.stars, color: Colors.orange, size: 22),
                SizedBox(width: 8),
                Text("Top 10 Most Selling", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            height: 200,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('outletId', arrayContains: outletId)
                  .orderBy('revenue', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No sales data yet."));

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final product = Product.fromFirestore(doc);
                    return _buildTopSellingCard(product, outletId);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 25),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text("Popular in $outletName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('products')
                .where('outletId', arrayContains: outletId)
                .limit(6)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(child: Text("No items available here.")),
                );
              }
              final List<Product> products = snapshot.data!.docs.map((doc) => Product.fromFirestore(doc)).toList();
              
              return ProductGrid(
                products: products,
                outletId: outletId,
                onRefresh: () => setState(() {}),
                imageEngine: _buildProductImage, 
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGlobalOnboardingPlaceholder() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Column(
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                height: 180,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(45),
                    bottomRight: Radius.circular(45),
                  ),
                ),
              ),
              Positioned(
                top: -50,
                right: -30,
                child: CircleAvatar(radius: 110, backgroundColor: Colors.white.withOpacity(0.06)),
              ),
              Positioned(
                bottom: -20,
                left: -20,
                child: CircleAvatar(radius: 70, backgroundColor: Colors.white.withOpacity(0.04)),
              ),
              const SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, 30, 28, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10),
                      Text(
                        "Welcome to",
                        style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "DesaMall",
                        style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 16),
                    child: Text(
                      "3 STEPS TO START SHOPPING",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1.2),
                    ),
                  ),
                  
                  _buildPremiumStepCard(
                    icon: Icons.storefront_rounded,
                    color: Colors.redAccent,
                    stepNumber: "01",
                    title: "Select Fulfilling Branch",
                    description: "Connect to a nearby DesaMall storefront hub to load localized store stocks instantly.",
                  ),
                  const SizedBox(height: 14),
                  _buildPremiumStepCard(
                    icon: Icons.grid_view_rounded,
                    color: Colors.orange,
                    stepNumber: "02",
                    title: "Explore Categories",
                    description: "Browse curated collections, view regional discounts, and add items into your active bag.",
                  ),
                  const SizedBox(height: 14),
                  _buildPremiumStepCard(
                    icon: Icons.payment_rounded,
                    color: Colors.green,
                    stepNumber: "03",
                    title: "Fast Secure Checkout",
                    description: "Confirm details securely, apply vouchers, and trace your delivery lines seamlessly.",
                  ),
                  
                  const SizedBox(height: 35),
                  
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/outlets'),
                      icon: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                      label: const Text(
                        "FIND NEAREST OUTLET",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStepCard({
    required IconData icon,
    required Color color,
    required String stepNumber,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                    ),
                    Text(
                      stepNumber,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color.withOpacity(0.25), fontFamily: 'Courier'),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTopSellingCard(Product product, String outletId) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(
          id: product.id,
          name: product.name, 
          price: product.price.toString(), 
          image: product.image, 
          outletId: outletId,
          stock: product.stock,
        )));
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 15, bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
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
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: _buildProductImage(product.image), // Added support here
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: const Text("HOT", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text("RM ${product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  void _navigateToCategory(String categoryName, String outletId) {
    Widget page;
    switch (categoryName) {
      case "Minuman": page = BeveragesPage(outletId: outletId); break;
      case "Keperluan Memasak": page = CookingEssentialsPage(outletId: outletId); break;
      case "Kelengkapan Berkebun": page = GardeningPage(outletId: outletId); break;
      case "Kelengkapan Penjagaan Rumah": page = HomeCarePage(outletId: outletId); break;
      case "Keperluan Bayi": page = NurseryPage(outletId: outletId); break;
      case "Snek / Makanan Ringan": page = SnacksPage(outletId: outletId); break;
      case "Suplemen Makanan": page = FoodSupplementPage(outletId: outletId); break;
      default: page = CategoriesPage(outletId: outletId);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildBadgeIcon(IconData icon, int count) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6, top: -6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5)),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

class ProductGrid extends StatelessWidget {
  final List<Product> products;
  final String outletId;
  final VoidCallback onRefresh;
  final Widget Function(String) imageEngine; // Passes down the image rendering engine safely

  const ProductGrid({
    Key? key, 
    required this.products, 
    required this.outletId, 
    required this.onRefresh,
    required this.imageEngine,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 0.7, crossAxisSpacing: 15, mainAxisSpacing: 15,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(
              id: product.id,
              name: product.name, 
              price: product.price.toString(), 
              image: product.image, 
              outletId: outletId,
              stock: product.stock,
            )));
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: imageEngine(product.image), // Handled here via engine callback
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text("RM ${product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 15)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 35,
                        child: ElevatedButton(
                          onPressed: () {
                            addItem(
                              product.name, 
                              product.price, 
                              product.image, 
                              outletId, 
                              id: product.id, 
                              stock: product.stock
                            );
                            onRefresh();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("${product.name} added to bag"), duration: const Duration(seconds: 1)),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.zero
                          ),
                          child: const Text("Add to Bag", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
  }
}

// 🎯 DYNAMIC FIRESTORE SEARCH DELEGATE
class ProductSearchDelegate extends SearchDelegate {
  final String outletId;

  ProductSearchDelegate({required this.outletId});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white70),
      ),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: Colors.white),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    if (query.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 60, color: Colors.grey),
            SizedBox(height: 10),
            Text("Search for products...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('outletId', arrayContains: outletId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No products found in this outlet."));
        }

        final filteredProducts = snapshot.data!.docs.map((doc) {
          return Product.fromFirestore(doc);
        }).where((product) {
          return product.name.toLowerCase().contains(query.toLowerCase());
        }).toList();

        if (filteredProducts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "No matches found for \"$query\"",
                style: const TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: filteredProducts.length,
          itemBuilder: (context, index) {
            final product = filteredProducts[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey.shade100,
                  // 🔑 Built-in lightweight decoder logic to ensure images load in search suggestion tiles
                  child: Builder(
                    builder: (context) {
                      String path = product.image;
                      try {
                        if (path.startsWith('http')) {
                          return Image.network(path, fit: BoxFit.cover);
                        }
                        if (path.startsWith('assets/')) {
                          return Image.asset(path, fit: BoxFit.cover);
                        }
                        String cleanBase64 = path.contains(',') ? path.split(',').last : path;
                        return Image.memory(
                          base64Decode(cleanBase64.trim()),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Icon(Icons.image, color: Colors.grey),
                        );
                      } catch (e) {
                        return const Icon(Icons.image, color: Colors.grey);
                      }
                    },
                  ),
                ),
              ),
              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text("RM ${product.price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailPage(
                  id: product.id,
                  name: product.name,
                  price: product.price.toString(),
                  image: product.image,
                  outletId: outletId,
                  stock: product.stock,
                )));
              },
            );
          },
        );
      },
    );
  }
}