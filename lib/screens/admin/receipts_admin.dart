import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; 
import 'dart:math'; 
import 'dart:io'; // 🚀 Added for handling local file paths
import 'package:path_provider/path_provider.dart'; // 🚀 Added for temporary document directories
import 'package:flutter_pdfview/flutter_pdfview.dart'; // 🚀 Added for rendering internal pop-up views

class ReceiptsAdmin extends StatefulWidget {
  final String branchAccess; 

  const ReceiptsAdmin({Key? key, this.branchAccess = 'all'}) : super(key: key);

  @override
  _ReceiptsAdminState createState() => _ReceiptsAdminState();
}

class _ReceiptsAdminState extends State<ReceiptsAdmin> {
  String _selectedFilter = "All";

  // A simple map to translate IDs to Names
  String _getCleanOutletName(String? outletId) {
    if (outletId == null || outletId.trim().isEmpty) return 'General Store';

    final Map<String, String> outletMap = {
      'lipis': 'DesaMall@Lipis',
      'kepala_batas': 'DesaMall@Kepala Batas',
      'ipoh': 'DesaMall@Ipoh',
    };

    return outletMap[outletId.trim()] ?? outletId;
  }

  // A helper to translate Admin branchAccess to Firestore outletId
  String _mapBranchAccessToOutletId(String branchAccess) {
    final Map<String, String> mapping = {
      'lipis': 'DesaMall@Lipis',
      'kepala_batas': 'DesaMall@Kepala Batas',
      'ipoh': 'DesaMall@Ipoh',
    };
    return mapping[branchAccess.toLowerCase()] ?? branchAccess;
  }

  String _generateTrackingNumber() {
    final random = Random();
    final int step1 = 10000 + random.nextInt(90000); 
    final int step2 = 10000 + random.nextInt(90000); 
    return "EP$step1$step2";
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    DateTime date = (timestamp as Timestamp).toDate();
    return "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _sendNotification(String customerUid, String orderId, String status, {String? trackingNum}) async {
    try {
      String title = 'Payment Status Update 🔔';
      String message = 'Your order #$orderId is being processed.';

      if (status == 'Approved') {
        title = 'Payment Approved! ✅';
        message = 'Your payment for Order #$orderId has been verified. Store is preparing your order!';
      } else if (status == 'Rejected') {
        title = 'Payment Rejected ❌';
        message = 'Your payment for Order #$orderId was rejected. Please re-upload a clear receipt.';
      } else if (status == 'Shipped') {
        title = 'Order Shipped! 🚀';
        message = 'Great news! Your order #$orderId has been shipped out via EasyParcel.${trackingNum != null ? ' Tracking No: $trackingNum' : ''}';
      }

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': customerUid, 
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(), 
        'isRead': false, 
      });
    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }

  // 🚀 Internal helper that builds the PDF pop-up view without jumping outside the app
  void _openInternalPdfPopUp(BuildContext context, String base64String, String customerName) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return FutureBuilder<String>(
          future: () async {
            String cleanBase64 = base64String.contains(',') ? base64String.split(',').last : base64String;
            final bytes = base64Decode(cleanBase64.trim());
            final dir = await getTemporaryDirectory();
            final file = File("${dir.path}/preview_receipt.pdf");
            await file.writeAsBytes(bytes, flush: true);
            return file.path;
          }(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text("Error Loading File"),
                content: Text("${snapshot.error}"),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Scaffold(
                  appBar: AppBar(
                    title: Text("$customerName's Receipt", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: const Color(0xFFD32F2F),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  body: PDFView(
                    filePath: snapshot.data!,
                    enableSwipe: true,
                    swipeHorizontal: false,
                    autoSpacing: true,
                    pageFling: true,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // UPDATED LOGIC: If branchAccess is 'all', show everything. Otherwise, filter by outletId.
    Query receiptQuery = FirebaseFirestore.instance.collection('receipts');

    if (widget.branchAccess != 'all') {
      receiptQuery = receiptQuery.where('outletId', isEqualTo: widget.branchAccess);
    }

    // Always order by timestamp
    receiptQuery = receiptQuery.orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF5350), Color(0xFFC62828)], 
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            child: Column(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                const Text(
                  "Receipt Verification", 
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Review customer uploads and manage points.", 
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 25),
                
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
                          selectedColor: const Color(0xFFD32F2F),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: const BorderSide(color: Colors.white),
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

                final filteredDocs = _selectedFilter == "All" 
                    ? docs 
                    : docs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == _selectedFilter).toList();

                if (filteredDocs.isEmpty) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_rounded, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text("No $_selectedFilter receipts found.", style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final docId = filteredDocs[index].id;
                    final String status = data['status'] ?? "Pending";
                    final bool isPdf = data['file_type'] == 'pdf';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPdf ? Icons.picture_as_pdf_rounded : Icons.receipt_long_rounded, 
                            color: _getStatusColor(status), 
                            size: 28
                          ),
                        ),
                        title: Text(
                          data['user_name'] ?? "Unknown Customer", 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: _getStatusColor(status), fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text("RM ${(data['total_price'] ?? 0.0).toStringAsFixed(2)}", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Sent: ${_formatTimestamp(data['timestamp'])}",
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
                        onTap: () => _showReceiptDetails(context, data, docId),
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

  void _showReceiptDetails(BuildContext context, Map<String, dynamic> data, String docId) {
    final String customerId = data['user_id'] ?? data['uid'] ?? "";
    final String orderId = docId;
    final double totalPrice = (data['total_price'] ?? 0.0).toDouble();

    final Timestamp receiptTime = data['timestamp'] as Timestamp;
    final DateTime receiptDate = receiptTime.toDate();
    final Timestamp startTime = Timestamp.fromDate(receiptDate.subtract(const Duration(minutes: 5)));
    final Timestamp endTime = Timestamp.fromDate(receiptDate.add(const Duration(minutes: 5)));

    final bool isPdf = data['file_type'] == 'pdf';
    final String currentStatus = data['status'] ?? "Pending";
    final String? trackingNumber = data['tracking_number'];

    final double pointsToEarn = data['points_earned'] != null
        ? (data['points_earned'] as num).toDouble()
        : (totalPrice > 100.0 ? totalPrice * 0.005 : 0.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('orders')
                .where('uid', isEqualTo: customerId)
                .where('timestamp', isGreaterThanOrEqualTo: startTime)
                .where('timestamp', isLessThanOrEqualTo: endTime)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 5), onTimeout: () {
                    throw Exception("Connection timed out.");
                }),
            builder: (context, orderSnapshot) {
              // 1. Loading State
              if (orderSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }

              // 2. Error State
              if (orderSnapshot.hasError) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Data loading issue.")));
              }

              // 3. Data Processing State
              Map<String, dynamic> orderData = {};
              String rawOutletId = data['outletId'] ?? "Main Store";

              if (orderSnapshot.hasData && orderSnapshot.data!.docs.isNotEmpty) {
                orderData = orderSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                
                var itemsRaw = orderData['items'];
                if (itemsRaw is Map && itemsRaw.isNotEmpty) {
                  rawOutletId = itemsRaw.values.first['outletId'] ?? rawOutletId;
                } else if (itemsRaw is List && itemsRaw.isNotEmpty) {
                  rawOutletId = itemsRaw[0]['outletId'] ?? rawOutletId;
                }
              }

              String displayedOutlet = _getCleanOutletName(rawOutletId);
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.center,
                      child: Text("Review Transaction", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 30),
                    _buildDetailRow("Customer", data['user_name'] ?? "Unknown"),
                    _buildDetailRow("Order ID", "#$orderId"),
                    _buildDetailRow("Sent On", _formatTimestamp(data['timestamp'])),
                    _buildDetailRow("Assigned Outlet", displayedOutlet),
                    if (trackingNumber != null) _buildDetailRow("Tracking No (EasyParcel)", trackingNumber, color: Colors.blueAccent, isBold: true),
                    _buildDetailRow("Delivery Address", data['shipping_address'] ?? data['address'] ?? "No Address Provided", isLongText: true),
                    _buildDetailRow("Total Paid", "RM ${totalPrice.toStringAsFixed(2)}", isBold: true),
                    _buildDetailRow("Reward Points", "+RM ${pointsToEarn.toStringAsFixed(2)}", color: Colors.green),
                    const SizedBox(height: 15),
                    const Text("Purchased Items", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 8),
                    if (orderSnapshot.connectionState == ConnectionState.waiting)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(color: Colors.redAccent)))
                    else
                      _buildOrderItemsSection(orderData), 

                    const SizedBox(height: 20),
                    const Text("Customer Payment Receipt Document", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: data['receipt_base64'] != null
                          ? (isPdf 
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(30),
                                  color: Colors.grey[100],
                                  child: Column(
                                    children: [
                                      const Icon(Icons.picture_as_pdf_rounded, size: 80, color: Colors.redAccent),
                                      const SizedBox(height: 10),
                                      const Text("PDF Receipt Uploaded", style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 10),
                                      ElevatedButton(
                                        onPressed: () {
                                          if (data['receipt_base64'] != null) {
                                            _openInternalPdfPopUp(
                                              context, 
                                              data['receipt_base64'].toString(),
                                              data['user_name'] ?? "Customer"
                                            );
                                          }
                                        }, 
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                                        child: const Text("VIEW PDF FILE", style: TextStyle(color: Colors.white)),
                                      )
                                    ],
                                  ),
                                )
                              : Image.memory(base64Decode(data['receipt_base64']), height: 260, width: double.infinity, fit: BoxFit.contain)
                            )
                          : const Center(child: Text("No File Found")),
                    ),
                    
                    const SizedBox(height: 30),

                    if (currentStatus == "Pending") ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _updateStatus(docId, "Rejected", customerId, orderId),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("REJECT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _updateStatus(docId, "Approved", customerId, orderId, pointsEarned: pointsToEarn),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ] else if (currentStatus == "Approved") ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green),
                            SizedBox(width: 10),
                            Expanded(child: Text("Receipt Verified. Order status: Preparing Order", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(docId, "Shipped", customerId, orderId),
                          icon: const Icon(Icons.local_shipping_rounded, color: Colors.white),
                          label: const Text("MARK AS SHIPPED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else if (currentStatus == "Shipped") ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_rounded, color: Colors.blue.shade700),
                            const SizedBox(width: 10),
                            Text("This order has been Shipped", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                            const SizedBox(width: 10),
                            Text("This receipt has been Rejected", style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color, bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: isLongText 
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color ?? Colors.black87)),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                value, 
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                  color: color ?? Colors.black87,
                ),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildOrderItemsSection(Map<String, dynamic> orderData) {
    var rawItems = orderData['items'] ?? orderData['products'] ?? orderData['orderedItems'];
    List<dynamic> itemsList = [];

    if (rawItems != null) {
      if (rawItems is List) {
        itemsList = rawItems;
      } else if (rawItems is Map) {
        var sortedKeys = rawItems.keys.toList()..sort((a, b) => a.toString().compareTo(b.toString()));
        for (var key in sortedKeys) {
          var entry = rawItems[key];
          if (entry is Map) {
            itemsList.add(entry);
          }
        }
      } else if (rawItems is String) {
        try {
          var decoded = jsonDecode(rawItems);
          if (decoded is List) itemsList = decoded;
        } catch (_) {}
      }
    }

    if (itemsList.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
        child: const Text("No item details found in this transaction record.", style: TextStyle(color: Colors.grey, fontSize: 12)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemsList.length,
        separatorBuilder: (context, i) => Divider(color: Colors.grey.shade200, height: 1),
        itemBuilder: (context, index) {
          final item = itemsList[index];
          
          if (item is! Map) {
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(item.toString(), style: const TextStyle(fontSize: 13)),
            );
          }

          String name = (item['productName'] ?? item['name'] ?? item['product_name'] ?? item['title'] ?? "Unknown Item").toString();
          
          var rawQty = item['quantity'] ?? item['qty'] ?? item['count'] ?? 1;
          int quantity = 1;
          if (rawQty is num) {
            quantity = rawQty.toInt();
          } else if (rawQty is String) {
            quantity = int.tryParse(rawQty) ?? 1;
          }

          var rawPrice = item['price'] ?? item['unitPrice'] ?? item['productPrice'] ?? 0.0;
          double price = 0.0;
          if (rawPrice is num) {
            price = rawPrice.toDouble();
          } else if (rawPrice is String) {
            price = double.tryParse(rawPrice.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
          }

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text("Qty: $quantity", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
                Text("RM ${(price * quantity).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _updateStatus(String docId, String newStatus, String customerId, String orderId, {double pointsEarned = 0.0}) async {
    if (Navigator.canPop(context)) Navigator.pop(context);
    try {
      if (customerId.isEmpty) throw "Could not find a valid Customer ID.";
      
      // 🎯 Update the receipt status first (Always allowed for branch managers)
      Map<String, dynamic> receiptUpdates = {'status': newStatus};
      String? trackingNum;

      if (newStatus == "Shipped") {
        trackingNum = _generateTrackingNumber();
        receiptUpdates['tracking_number'] = trackingNum;
      }

      await FirebaseFirestore.instance.collection('receipts').doc(docId).update(receiptUpdates);

      // 🎯 SECURITY SAFEPOINT BLOCK: Updates loyalty profiles only if admin rules allow it
      if (newStatus == "Approved" && pointsEarned > 0.0) {
        try {
          WriteBatch loyaltyBatch = FirebaseFirestore.instance.batch();
          DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(customerId);
          
          loyaltyBatch.update(userRef, {
            'reward_points': FieldValue.increment(pointsEarned),
          });

          DocumentReference rewardLogRef = userRef.collection('rewards_history').doc();
          loyaltyBatch.set(rewardLogRef, {
            'title': 'Earned Points from Receipt Verification',
            'points': pointsEarned,
            'type': 'credit',
            'timestamp': FieldValue.serverTimestamp(),
            'associatedOrderId': orderId,
          });

          await loyaltyBatch.commit();
        } catch (authError) {
          // If branch admin lacks rule rights to touch the user profile, catch gracefully
          // allowing status changes to continue working perfectly!
          debugPrint("⚠️ Loyalty update skipped or restricted by Firestore rules: $authError");
        }
      }

      await _sendNotification(customerId, orderId, newStatus, trackingNum: trackingNum);
    } catch (e) {
      debugPrint("❌ Update Error: $e");
    }
  }
}