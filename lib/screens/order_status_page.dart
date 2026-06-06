import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'shipping_progress_page.dart'; // Ensure this import is correct

class OrderStatusPage extends StatelessWidget {
  final User? user = FirebaseAuth.instance.currentUser;
  final String? filterStatus; 

  OrderStatusPage({this.filterStatus});

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance
        .collection('receipts')
        .where('uid', isEqualTo: user?.uid);

    if (filterStatus != null) {
      query = query.where('status', isEqualTo: filterStatus);
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          filterStatus != null ? "$filterStatus Receipts" : "Receipt History", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No ${filterStatus ?? ''} receipts found.",
                    style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String status = data['status'] ?? "Pending";
              final String docId = docs[index].id;
              final String date = data['timestamp'] != null 
                  ? (data['timestamp'] as Timestamp).toDate().toString().substring(0, 16)
                  : "Recently";

              final dynamic rawPrice = data['total_price'];
              double priceValue = 0.0;
              if (rawPrice is num) priceValue = rawPrice.toDouble();
              else priceValue = double.tryParse(rawPrice.toString()) ?? 0.0;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: _buildStatusIcon(status),
                  title: Text("Ref: ${docId.substring(0, 8).toUpperCase()}", 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(date, style: const TextStyle(fontSize: 12)),
                  trailing: _buildStatusChip(status),
                  children: [
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (status == "Rejected") ...[
                            const Text("Rejection Reason:", 
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            Text(data['remarks'] ?? "Invalid receipt.", 
                                style: const TextStyle(color: Colors.black87)),
                            const SizedBox(height: 12),
                          ],
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showFullImage(context, data['receipt_base64']),
                                child: Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200], borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!)
                                  ),
                                  child: data['receipt_base64'] != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.memory(base64Decode(data['receipt_base64']), fit: BoxFit.cover),
                                        )
                                      : const Icon(Icons.image_not_supported, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Amount: RM ${priceValue.toStringAsFixed(2)}", 
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Text("Click image to enlarge", 
                                        style: TextStyle(fontSize: 11, color: Colors.blue)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // 🎯 NEW: TRACK ORDER BUTTON (Supports Approved & Shipped states dynamically)
                          if (status != "Rejected" && status != "Unpaid")
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ShippingProgressPage(
                                          address: data['shipping_address'] ?? data['address'] ?? "No Address Provided",
                                          total: priceValue,
                                          currentStatus: status, // Pass status here!
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.track_changes, color: Colors.white),
                                  label: const Text("TRACK SHIPPING STATUS", style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    if (status == "Approved" || status == "Shipped" || status == "Delivered") return const Icon(Icons.check_circle, color: Colors.green);
    if (status == "Rejected") return const Icon(Icons.cancel, color: Colors.red);
    return const Icon(Icons.hourglass_top, color: Colors.orange);
  }

  Widget _buildStatusChip(String status) {
    Color color = (status == "Approved" || status == "Delivered") 
        ? Colors.green 
        : (status == "Shipped" 
            ? Colors.blueAccent 
            : (status == "Rejected" ? Colors.red : Colors.orange));
            
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showFullImage(BuildContext context, String? base64) {
    if (base64 == null) return;
    showDialog(context: context, builder: (context) => Dialog(backgroundColor: Colors.transparent, child: Image.memory(base64Decode(base64))));
  }
}