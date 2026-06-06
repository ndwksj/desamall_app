import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class ReceiptsHistoryCustomer extends StatefulWidget {
  final String initialFilter;
  const ReceiptsHistoryCustomer({Key? key, this.initialFilter = "All"}) : super(key: key);

  @override
  _ReceiptsHistoryCustomerState createState() => _ReceiptsHistoryCustomerState();
}

class _ReceiptsHistoryCustomerState extends State<ReceiptsHistoryCustomer> {
  // 🎯 Updated: State string now initializes automatically matching the parameter sent from profile page
  late String _selectedFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Dynamically match selection string values safely 
    _selectedFilter = widget.initialFilter;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    DateTime date = (timestamp as Timestamp).toDate();
    return "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  int minOf(int a, int b) => a < b ? a : b;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view your receipt history.")),
      );
    }

    Query receiptQuery = FirebaseFirestore.instance
        .collection('receipts')
        .where('uid', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("My Receipts History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 25),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search Order ID...",
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ["All", "Pending", "Approved", "Shipped", "Rejected"].map((status) {
                      bool isSelected = _selectedFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (val) => setState(() => _selectedFilter = status),
                          selectedColor: Colors.white,
                          backgroundColor: Colors.red[700],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.redAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide.none,
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: receiptQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                final docs = snapshot.data!.docs;
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final statusMatch = (_selectedFilter == "All" || data['status'] == _selectedFilter);
                  final searchMatch = _searchController.text.isEmpty || 
                                     (data['order_id']?.toString().toLowerCase() ?? doc.id.toLowerCase()).contains(_searchController.text.toLowerCase());
                  return statusMatch && searchMatch;
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No order history found.", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final docId = filteredDocs[index].id;
                    final String status = data['status'] ?? "Pending";
                    final bool isPdf = data['file_type'] == 'pdf';
                    final String displayId = data['order_id'] ?? docId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), shape: BoxShape.circle), child: Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.receipt_long_rounded, color: _getStatusColor(status), size: 24)),
                        title: Text("Order #${displayId.substring(0, minOf(5, displayId.length))}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _getStatusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: TextStyle(color: _getStatusColor(status), fontSize: 9, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 8),
                            Text("RM ${(data['total_price'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ]),
                          const SizedBox(height: 4),
                          Text("Uploaded: ${_formatTimestamp(data['timestamp'])}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        ]),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                        onTap: () => _showCustomerReceiptDetails(context, data, docId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == "Approved") return Colors.green;
    if (status == "Shipped") return Colors.blueAccent;
    if (status == "Rejected") return Colors.red;
    return Colors.orange;
  }

  void _showCustomerReceiptDetails(BuildContext context, Map<String, dynamic> data, String docId) {
    final double totalPrice = (data['total_price'] ?? 0.0).toDouble();
    final String currentStatus = data['status'] ?? "Pending";
    final String? trackingNumber = data['tracking_number'];
    final double pointsToEarn = data['points_earned'] != null 
    ? (data['points_earned'] as num).toDouble() 
    : (totalPrice > 100.0 ? totalPrice * 0.005 : 0.0);
    
    final String targetOrderId = (data['order_id'] != null && data['order_id'].toString().isNotEmpty) ? data['order_id'] : docId;
    final String customerId = data['uid'] ?? FirebaseAuth.instance.currentUser?.uid ?? "";

    // Calculate time matrix offsets for deep transaction reconciliation matching
    final Timestamp receiptTime = data['timestamp'] as Timestamp;
    final DateTime receiptDate = receiptTime.toDate();
    final Timestamp startTime = Timestamp.fromDate(receiptDate.subtract(const Duration(minutes: 5)));
    final Timestamp endTime = Timestamp.fromDate(receiptDate.add(const Duration(minutes: 5)));

    // 🔑 NEW METHOD DETECTOR: Detect fulfillment strategy based on explicit field flag or address string contents
    bool isSelfPickup = data['delivery_method'] == "Self-Pickup" || 
                        (data['shipping_address']?.toString().startsWith("Self-Pickup") ?? false) || 
                        (data['address']?.toString().startsWith("Self-Pickup") ?? false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.80, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (context, scrollController) => FutureBuilder<Map<String, dynamic>>(
          // 🔑 DEEP RESOLUTION MATRIX: First checks explicit profile page data, then fallback queries
          future: () async {
            try {
              // 1. Check if the active profile document map data passed down already contains items directly
              if (data.containsKey('items') && data['items'] != null) {
                return Map<String, dynamic>.from(data);
              }

              // 2. Fallback: Query the main orders collection by Document ID
              DocumentSnapshot docSnap = await FirebaseFirestore.instance.collection('orders').doc(targetOrderId).get();
              if (docSnap.exists && docSnap.data() != null) {
                return Map<String, dynamic>.from(docSnap.data() as Map);
              }
              
              // 3. Fallback: Query matching context time metrics window
              QuerySnapshot querySnap = await FirebaseFirestore.instance
                  .collection('orders')
                  .where('uid', isEqualTo: customerId)
                  .where('timestamp', isGreaterThanOrEqualTo: startTime)
                  .where('timestamp', isLessThanOrEqualTo: endTime)
                  .limit(1)
                  .get();

              if (querySnap.docs.isNotEmpty) {
                return Map<String, dynamic>.from(querySnap.docs.first.data() as Map);
              }
            } catch (e) {
              debugPrint("Error fetching item data: $e");
            }
            return <String, dynamic>{};
          }(),
          builder: (context, orderSnapshot) {
            Map<String, dynamic> orderData = orderSnapshot.data ?? {};
            String assignedOutlet = "Verifying Outlet...";

            if (orderData.isNotEmpty) {
              String outletId = (orderData['outletId'] ?? data['outlet'] ?? data['outletId'] ?? "").toString();

              Map<String, String> outletMap = {
                "outlets001": "DesaMall@Lipis",
                "1qtcFaIzM9dUhqOVARH3": "DesaMall@Kepala Batas",
                "outlets003": "DesaMall@Ipoh",
              };

              assignedOutlet = outletMap[outletId] ?? (orderData['outletName'] ?? data['outletId'] ?? "Main Store");
              
              // Optional: Debugging line to see what is being read
              print("DEBUG: Read ID '$outletId' -> Assigned '$assignedOutlet'");
            } else {
              // Fallback mapping if order snapshot lookup returned empty initially
              String fallbackId = (data['outletId'] ?? data['outlet'] ?? "").toString();
              Map<String, String> outletMap = {
                "lipis": "DesaMall@Lipis",
                "kepala_batas": "DesaMall@Kepala Batas",
                "ipoh": "DesaMall@Ipoh",
              };
              assignedOutlet = outletMap[fallbackId.toLowerCase()] ?? (fallbackId.isNotEmpty ? fallbackId : "Main Store");
            }

            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(alignment: Alignment.center, child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  const Align(alignment: Alignment.center, child: Text("Receipt Verification Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  const Divider(height: 30),
                  _buildDetailRow("Order Reference", "#${targetOrderId.substring(0, minOf(5, targetOrderId.length))}"),
                  _buildDetailRow("Submission Date", _formatTimestamp(data['timestamp'])),
                  _buildDetailRow("Assigned Outlet", assignedOutlet, isBold: true),
                  _buildDetailRow("Verification Status", currentStatus, color: _getStatusColor(currentStatus), isBold: true),
                  
                  if (currentStatus == "Shipped") ...[
                    const Divider(height: 25),
                    isSelfPickup 
                    ? Container(
                        width: double.infinity, 
                        padding: const EdgeInsets.all(14), 
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            const Row(children: [Icon(Icons.storefront_rounded, color: Colors.green, size: 20), SizedBox(width: 8), Text("Self-Pickup Collection Ready", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13))]),
                            const SizedBox(height: 6),
                            Text("Your order is fully prepared at $assignedOutlet.", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                            const SizedBox(height: 2),
                            const Text("Status: Please visit the outlet counter to collect your items.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                          ],
                        ),
                      )
                    : trackingNumber != null 
                        ? Container(
                            width: double.infinity, 
                            padding: const EdgeInsets.all(14), 
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                const Row(children: [Icon(Icons.local_shipping_rounded, color: Colors.blueAccent, size: 20), SizedBox(width: 8), Text("Courier Assignment", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 13))]),
                                const SizedBox(height: 6),
                                Text("Logistics Partner: EasyParcel Malaysia", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text("Tracking Number: $trackingNumber", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13)),
                              ],
                            ),
                          )
                        : const SizedBox(),
                  ],
                  const Divider(height: 25),
                  // 🔑 OPTIMIZATION: Dynamically re-labels context title text description rows smoothly
                  _buildDetailRow(
                    isSelfPickup ? "Collection Location" : "Delivery Address", 
                    data['shipping_address'] ?? data['address'] ?? "No Address Provided", 
                    isLongText: true
                  ),
                  _buildDetailRow("Total Paid Amount", "RM ${totalPrice.toStringAsFixed(2)}", isBold: true),
                  _buildDetailRow("Earned Cashback Points", "+RM ${pointsToEarn.toStringAsFixed(2)}", color: Colors.green),
                  const SizedBox(height: 20),
                  const Text("Items Ordered", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                  const SizedBox(height: 8),
                  orderSnapshot.connectionState == ConnectionState.waiting
                      ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: Colors.redAccent)))
                      : _buildOrderItemsSection(orderData, data),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color, bool isLongText = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 10.0),
      child: isLongText ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 2), Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color ?? Colors.black87))])
          : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(width: 20), Expanded(child: Text(value, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color ?? Colors.black87)))])
    );
  }

  Widget _buildOrderItemsSection(Map<String, dynamic> orderData, Map<String, dynamic> receiptData) {
    var rawItems = orderData['items'];
    List<dynamic> itemsList = [];
    if (rawItems != null) {
      if (rawItems is List) itemsList = rawItems;
      else if (rawItems is Map) itemsList = rawItems.values.toList();
      else if (rawItems is String) { try { var decoded = jsonDecode(rawItems); if (decoded is List) itemsList = decoded; } catch (_) {} }
    }
    if (itemsList.isEmpty) {
      return Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Bulk Checkout Package Transaction", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)), Text("RM ${(receiptData['total_price'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
      );
    }
    return Container(decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: itemsList.length, separatorBuilder: (context, i) => Divider(color: Colors.grey.shade200, height: 1),
        itemBuilder: (context, index) {
          final item = itemsList[index];
          String name = item['productName'] ?? item['name'] ?? "Unknown Item";
          int quantity = (item['quantity'] ?? item['qty'] ?? 1).toInt();
          double price = (item['price'] ?? 0.0).toDouble();
          return Padding(padding: const EdgeInsets.all(12.0),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(height: 2), Text("Qty: $quantity", style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])), Text("RM ${(price * quantity).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))]),
          );
        },
      ),
    );
  }
}