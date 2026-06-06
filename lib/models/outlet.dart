class Outlet {
  final String id;
  final String name;
  final String category;
  final String status; // Open/Closed
  final double rating;
  final String imagePath;

  Outlet({
    required this.id, 
    required this.name, 
    required this.category, 
    required this.status, 
    required this.rating, 
    required this.imagePath
  });
}