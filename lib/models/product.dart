import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final double price;
  final String image;
  final List<dynamic> outletId;
  final int stock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.image,
    required this.outletId,
    this.stock = 0,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    var rawStock = data['stock'] ?? 0;
    int parsedStock = (rawStock is String) 
        ? (int.tryParse(rawStock) ?? 0) 
        : (rawStock as num).toInt();

    var rawPrice = data['price'] ?? 0.0;
    double parsedPrice = (rawPrice is String) 
        ? (double.tryParse(rawPrice) ?? 0.0) 
        : (rawPrice as num).toDouble();

    // 🔑 Fixes the fallback check so 'image' and 'imageUrl' strings are parsed correctly
    String imagePath = data['image'] ?? data['imageUrl'] ?? '';

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      price: parsedPrice,
      image: imagePath, 
      outletId: data['outletId'] ?? [],
      stock: parsedStock, 
    );
  }
}