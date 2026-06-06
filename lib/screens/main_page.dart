import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';

class MainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner section
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                'Visit Our Store!',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          CustomButton(
            text: 'Check',
            onPressed: () {
              // TODO: Navigate to store details later
            },
          ),

          SizedBox(height: 30),
          Text('New', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text('You’ve never seen it before!'),
          SizedBox(height: 10),

          CustomButton(
            text: 'View all',
            onPressed: () {
              // TODO: Navigate to product listing
            },
          ),
        ],
      ),
    );
  }
}

