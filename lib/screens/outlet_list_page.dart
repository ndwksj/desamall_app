import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'outlet_detail_page.dart'; // Ensure this path is correct

class OutletListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Our Outlets"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('outlets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No outlets found."));
          }

          final outlets = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(12),
            itemCount: outlets.length,
            itemBuilder: (context, index) {
              final data = outlets[index].data() as Map<String, dynamic>;
              final String imagePath = data['image'] ?? "";

              return Card(
                margin: EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 60,
                      child: imagePath.startsWith('http')
                          ? Image.network(imagePath, fit: BoxFit.cover)
                          : Image.asset(imagePath, fit: BoxFit.cover, 
                              errorBuilder: (c,e,s) => Icon(Icons.store)),
                    ),
                  ),
                  title: Text(data['name'] ?? "Unknown Outlet", 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['address'] ?? "", maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to the detail page you just made!
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OutletDetailPage(
                          name: data['name'] ?? "",
                          address: data['address'] ?? "",
                          imagePath: imagePath,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}