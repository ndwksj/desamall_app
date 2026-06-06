import 'package:flutter/material.dart';

class ShippingProgressPage extends StatelessWidget {
  final String? address;
  final double? total;
  final String? currentStatus; 
  final String? outletId;
  final String? outletName;

  const ShippingProgressPage({
    Key? key, 
    this.address, 
    this.total, 
    this.currentStatus,
    this.outletId,
    this.outletName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isApproved = currentStatus == "Approved" || currentStatus == "Shipped" || currentStatus == "Delivered";
    bool isShipped = currentStatus == "Shipped" || currentStatus == "Delivered";
    bool isDelivered = currentStatus == "Delivered";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Track Order", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Prevents backing into payment screen
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
            decoration: const BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Column(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 50, color: Colors.white),
                const SizedBox(height: 10),
                Text(isDelivered ? "Order Delivered!" : "Order is on its way!", 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    children: [
                      Text("Total Paid: RM ${total?.toStringAsFixed(2) ?? '0.00'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Shipping to: ${address ?? 'Home Address'}", textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
              children: [
                _buildProgressStep(
                  title: "Receipt Uploaded",
                  subtitle: "Payment received by the system.",
                  isCompleted: true, 
                  isLast: false,
                ),
                _buildProgressStep(
                  title: "Payment Verified",
                  subtitle: isApproved ? "Admin has verified your payment." : "Waiting for admin verification.",
                  isCompleted: isApproved,
                  isLast: false,
                ),
                _buildProgressStep(
                  title: "Order Shipped",
                  subtitle: isShipped ? "Your items are with the courier." : "Preparing your package.",
                  isCompleted: isShipped,
                  isLast: false,
                ),
                _buildProgressStep(
                  title: "Delivered",
                  subtitle: isDelivered ? "Enjoy your items!" : "Courier is arriving soon.",
                  isCompleted: isDelivered,
                  isLast: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () {
                // 🎯 FIX: Persistently pass back the outlet data to restore branch context on home screen
                Navigator.pushNamedAndRemoveUntil(
                  context, 
                  '/home', 
                  (route) => false,
                  arguments: {
                    'id': outletId ?? "",
                    'name': outletName ?? "DesaMall Outlet",
                  },
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: const Text("BACK TO HOME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep({required String title, required String subtitle, required bool isCompleted, required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: isCompleted ? Colors.green : Colors.grey[300]!, width: 2),
                ),
                child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              if (!isLast)
                Expanded(child: Container(width: 3, margin: const EdgeInsets.symmetric(vertical: 4), color: isCompleted ? Colors.green : Colors.grey[200])),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCompleted ? Colors.black87 : Colors.grey[500])),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(fontSize: 13, color: isCompleted ? Colors.grey[600] : Colors.grey[400])),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}