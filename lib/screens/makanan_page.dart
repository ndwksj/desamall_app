import 'package:flutter/material.dart';

class MakananPage extends StatelessWidget {
  final List<Map<String, dynamic>> makananItems = [
    {"name": "Keropok", "price": "RM5.00", "image": Icons.fastfood},
    {"name": "Nasi Lemak", "price": "RM8.00", "image": Icons.rice_bowl},
    {"name": "Mee Goreng", "price": "RM7.50", "image": Icons.dinner_dining},
    {"name": "Satay", "price": "RM12.00", "image": Icons.local_dining},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Makanan'),
        backgroundColor: Colors.deepPurple,
      ),
      body: GridView.builder(
        padding: EdgeInsets.all(12),
        itemCount: makananItems.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          final item = makananItems[index];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item["image"], size: 60, color: Colors.redAccent),
                SizedBox(height: 10),
                Text(item["name"],
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Text(item["price"],
                    style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          );
        },
      ),
    );
  }
}
