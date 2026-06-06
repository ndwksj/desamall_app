import 'package:flutter/material.dart';
import 'upload_receipt_page.dart';

class PaymentPage extends StatelessWidget {
  final String? selectedAddress;
  final double totalAmount;
  final String? selectedOutlet; 
  final String? orderId; 
  final String outletId;
  final bool isPointsRedeemed; // Added to capture if points were applied on checkout

  const PaymentPage({
    Key? key,
    required this.selectedAddress,
    required this.totalAmount,
    this.selectedOutlet, 
    this.orderId, 
    required this.outletId,
    this.isPointsRedeemed = false, // Defaulted to false to keep it safe
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔑 Check if this is a self-pickup order to dynamically update the text label contextually
    bool isSelfPickup = selectedAddress?.startsWith("Self-Pickup") ?? false;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Payment details:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Total Amount: RM ${totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Outlet: ${selectedOutlet ?? 'General'}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              const Text(
                "1. Please scan QR Code below.\n2. After payment, upload your receipt.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Image.asset(
                "assets/qr.png",
                height: 300,
                width: 300,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.qr_code_2, size: 200, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  // 🔑 Dynamically switches label text context without modifying original layout spacing
                  isSelfPickup 
                      ? "Pickup location: ${selectedAddress ?? 'No address selected'}"
                      : "Shipping to: ${selectedAddress ?? 'No address selected'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  elevation: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  debugPrint("DEBUG: About to navigate to UploadReceiptPage with outletId: $outletId");
                  
                  // 🔑 NEW RULE: Multiplier changed to 0.005 and points only given if totalAmount > 100
                  double calculatedPoints = 0.0;
                  if (totalAmount > 100.0) {
                    calculatedPoints = totalAmount * 0.005;
                  } else {
                    calculatedPoints = 0.0;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UploadReceiptPage(
                        selectedAddress: selectedAddress,
                        totalAmount: totalAmount,
                        selectedOutlet: selectedOutlet, 
                        pointsEarned: calculatedPoints,
                        orderId: orderId,
                        outletId: outletId,
                        // This can pass the state along to the final submit step to update Firestore
                        isPointsRedeemed: isPointsRedeemed, 
                      ),
                    ),
                  );
                },
                child: const Text(
                  "UPLOAD YOUR RECEIPT HERE",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}