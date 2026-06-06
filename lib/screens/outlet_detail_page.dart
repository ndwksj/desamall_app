import 'package:flutter/material.dart';

class OutletDetailPage extends StatelessWidget {
  final String name;
  final String address;
  final String imagePath;

  // 🔹 Constructor remains the same, but we handle the image logic inside the build
  OutletDetailPage({
    required this.name, 
    required this.address, 
    required this.imagePath
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(name), 
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 SMART IMAGE HEADER
            // Automatically detects if image is from Assets or a Web URL
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: imagePath.startsWith('http')
                  ? Image.network(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Icon(Icons.store, size: 80, color: Colors.grey),
                    )
                  : Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Icon(Icons.store, size: 80, color: Colors.grey),
                    ),
            ),

            // 🔹 OUTLET INFORMATION
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.black87
                    ),
                  ),
                  
                  Divider(height: 30, thickness: 1.5),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Location Details",
                              style: TextStyle(
                                fontSize: 14, 
                                color: Colors.grey[600], 
                                fontWeight: FontWeight.w600
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 18, 
                                height: 1.5, 
                                color: Colors.black87
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 40),

                  // 🔹 OPTIONAL: ADD A BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Logic to open Google Maps could go here later!
                      },
                      icon: Icon(Icons.map),
                      label: Text("OPEN IN GOOGLE MAPS"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                    ),
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