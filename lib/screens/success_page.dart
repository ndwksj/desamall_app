import 'package:flutter/material.dart';

class SuccessPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Success!"), backgroundColor: Colors.redAccent),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag, size: 100, color: Colors.redAccent),
            SizedBox(height: 20),
            Text("Your order will be delivered soon.", style: TextStyle(fontSize: 18)),
            Text("Thank you for choosing our app!"),
            SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text("CONTINUE SHOPPING"),
            ),
          ],
        ),
      ),
    );
  }
}
