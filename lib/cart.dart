import 'models/product.dart';

List<Map<String, dynamic>> cart = [];

void addToCart(Product product, String outletId, {int stock = 0, int quantity = 1}) {
  addItem(
    product.name, 
    product.price, 
    product.image, 
    outletId, 
    id: product.id, 
    stock: stock, 
    quantity: quantity
  );
}

void addItem(String name, double price, String image, String outletId, {String? id, int stock = 0, int quantity = 1}) {
  final index = cart.indexWhere((item) => item["name"] == name && item["outletId"] == outletId);
  
  if (index >= 0) {
    // HARD LIMIT: Check if adding quantity exceeds total database stock
    if (cart[index]["quantity"] + quantity <= stock) {
      cart[index]["quantity"] += quantity;
    } else {
      cart[index]["quantity"] = stock; // Set to max possible
    }
    cart[index]["stock"] = stock; // ✅ Save/Update stock count in state
  } else {
    // HARD LIMIT: New item added must be less than or equal to stock
    int initialQty = quantity <= stock ? quantity : stock;
    if (initialQty > 0) {
      cart.add({
        "id": id,
        "name": name,
        "price": price,
        "quantity": initialQty,
        "stock": stock, // ✅ FIXED: Saving stock variable so CartPage can read it!
        "image": image,
        "outletId": outletId, 
      });
    }
  }
}

List<Map<String, dynamic>> getCartItemsByOutlet(String outletId) {
  return cart.where((item) => item["outletId"] == outletId).toList();
}

void removeItem(String name, [String? outletId]) {
  if (outletId != null) {
    cart.removeWhere((item) => item["name"] == name && item["outletId"] == outletId);
  } else {
    cart.removeWhere((item) => item["name"] == name);
  }
}

void increaseQuantity(String name, String outletId, [int stock = 0]) {
  final index = cart.indexWhere((item) => item["name"] == name && item["outletId"] == outletId);
  if (index >= 0) {
    // If stock value isn't explicitly passed, pull it directly from the map item memory
    int currentStock = stock > 0 ? stock : (cart[index]["stock"] ?? 0);
    if (cart[index]["quantity"] < currentStock) {
      cart[index]["quantity"]++;
    }
  }
}

void decreaseQuantity(String name, String outletId) {
  final index = cart.indexWhere((item) => item["name"] == name && item["outletId"] == outletId);
  if (index >= 0) {
    if (cart[index]["quantity"] > 1) {
      cart[index]["quantity"]--;
    } else {
      removeItem(name, outletId);
    }
  }
}

double getTotal(String outletId) {
  return getCartItemsByOutlet(outletId).fold(0, (sum, item) => sum + (item["price"] * item["quantity"]));
}

void clearCart() {
  cart.clear();
}

int getCartCount(String outletId) {
  return getCartItemsByOutlet(outletId).fold<int>(0, (sum, item) => sum + (item["quantity"] as int));
}

int getItemQuantityInCart(String name, String outletId) {
  final index = cart.indexWhere((item) => item["name"] == name && item["outletId"] == outletId);
  return index >= 0 ? cart[index]["quantity"] : 0;
}