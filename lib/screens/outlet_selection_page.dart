import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/outlet.dart';

class OutletSelectionPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- PREMIUM GRADIENT HEADER ---
          Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.location_on_outlined, color: Colors.white, size: 28),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white, size: 28),
                          onPressed: () => showSearch(context: context, delegate: OutletSearchDelegate()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Welcome to DesaMall",
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Select a branch near you to start exploring premium local products.",
                      style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 30, 24, 15),
            child: Row(
              children: [
                Icon(Icons.store_mall_directory_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Text("Available Outlets", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('outlets').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Connection Error."));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    
                    final outlet = Outlet(
                      id: docs[index].id, 
                      name: data['name'] ?? 'Unknown Outlet',
                      category: 'DesaMall Branch', 
                      status: 'Open',              
                      rating: 4.8,                
                      imagePath: data['image'] ?? 'assets/outlets/lipis.jpg',
                    );

                    return _buildOutletCard(context, outlet, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletCard(BuildContext context, Outlet outlet, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context, 
        '/home', 
        arguments: {
          'id': outlet.id,
          'name': outlet.name,
        },
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                  child: Image.asset(
                    outlet.imagePath,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.grey[100],
                      child: const Icon(Icons.store_rounded, size: 50, color: Colors.grey),
                    ),
                  ),
                ),
                // Premium Status Tag
                Positioned(
                  top: 15,
                  left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text("OPEN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                // Rating Tag
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                        SizedBox(width: 4),
                        Text("4.8", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(outlet.name, 
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)), 
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(data['address'] ?? 'No address provided', 
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Search Delegate UI Cleanup
class OutletSearchDelegate extends SearchDelegate {
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults();

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('outlets').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final results = snapshot.data!.docs.where((doc) => doc['name'].toString().toLowerCase().contains(query.toLowerCase())).toList();
        if (results.isEmpty) return const Center(child: Text("No outlets found."));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final data = results[index].data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.storefront, color: Colors.redAccent),
              title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pushNamed(context, '/home', arguments: {'name': data['name'], 'id': results[index].id}),
            );
          },
        );
      },
    );
  }
}