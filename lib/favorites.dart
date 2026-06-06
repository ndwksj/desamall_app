// lib/favorites.dart

List<Map<String, dynamic>> favorites = [];

void addFavorite(String name, double price, String image) {
  final index = favorites.indexWhere((item) => item["name"] == name);
  if (index == -1) {
    favorites.add({
      "name": name,
      "price": price,
      "image": image,
    });
  }
  print("Favorites now: $favorites");
}

void removeFavorite(String name) {
  favorites.removeWhere((item) => item["name"] == name);
}

bool isFavorite(String name) {
  return favorites.any((item) => item["name"] == name);
}

// 🔹 Badge counter for bottom nav
int getFavoritesCount() {
  return favorites.length;
}
