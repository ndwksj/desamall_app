import 'package:flutter/material.dart';
import '../models/product.dart';
import '../screens/product_detail_page.dart';

class ProductGrid extends StatelessWidget {
  final List<Product> products;

  ProductGrid({required this.products});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
      itemBuilder: (context, index) {
        final product = products[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ProductDetailPage(
  name: product.name,
  price: "RM${product.price.toStringAsFixed(2)}",
  image: product.image,
  oldPrice: product.oldPrice, // optional
),
            ));
          },
          child: Card(
            child: Column(
              children: [
                Image.asset(product.image, height: 100),
                Text(product.name),
                Text("RM${product.price.toStringAsFixed(2)}"),
              ],
            ),
          ),
        );
      },
    );
  }
}
