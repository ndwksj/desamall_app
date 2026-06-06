import 'package:flutter/material.dart';

class ProductsPage extends StatelessWidget {
  final List<Map<String, dynamic>> products = [
    {"name": "Red T-Shirt", "price": "RM29.90", "image": Icons.shopping_bag},
    {"name": "Blue Jeans", "price": "RM89.90", "image": Icons.shopping_bag},
    {"name": "Sneakers", "price": "RM129.90", "image": Icons.shopping_bag},
    {"name": "Handbag", "price": "RM199.90", "image": Icons.shopping_bag},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(product["image"], size: 60, color: Colors.redAccent),
                SizedBox(height: 10),
                Text(product["name"], style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(product["price"], style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          );
        },
      ),
    );
  }
}
