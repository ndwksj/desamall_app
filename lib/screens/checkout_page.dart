import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // 🔑 Native Flutter decoder for administrative uploaded product pictures
import 'payment_page.dart';

class CheckoutPage extends StatefulWidget {
  final List<dynamic> items;
  final double subtotal;
  final String outletId;
  final double deliveryFee = 5.0;

  CheckoutPage({required this.items, required this.subtotal, required this.outletId});

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final user = FirebaseAuth.instance.currentUser;
  String? _selectedAddress;
  double _pointsDiscount = 0.0;
  double _userPoints = 0.0;
  bool _isPointsRedeemed = false; // Tracks whether the user has toggled the switch
  
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  // 🛠️ FIX: Removed 'late' and initialized variables directly in initState safely
  List<dynamic> _localItems = [];
  double _localSubtotal = 0.0;

  // 🔑 NEW STATES: Track whether customer selects Self-Pickup or Delivery
  String _selectedDeliveryMethod = "Delivery"; // Options: "Delivery" or "Self-Pickup"

  @override
  void initState() {
    super.initState();
    // Immediate, non-async initialization ensures these are never missing when build() runs
    _localItems = List.from(widget.items);
    _localSubtotal = widget.subtotal;
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userData = data;
          _userPoints = (data['reward_points'] ?? 0.0).toDouble();
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Reactive inline state incrementers to dynamically update checkout figures
  void _updateItemQuantity(int index, int newQuantity) {
    if (newQuantity < 1) return;

    var item = _localItems[index];
    int maxStock = 0;
    if (item["stock"] != null) {
      maxStock = (item["stock"] is String) ? (int.tryParse(item["stock"]) ?? 0) : (item["stock"] as num).toInt();
    }

    if (maxStock > 0 && newQuantity > maxStock) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot add more. Only $maxStock units available in stock.")),
      );
      return;
    }

    setState(() {
      item['quantity'] = newQuantity;
      // Re-calculate the absolute subtotal dynamically across the list instance
      _localSubtotal = _localItems.fold(0.0, (sum, element) {
        double price = (element['price'] is num) ? element['price'].toDouble() : double.tryParse(element['price'].toString()) ?? 0.0;
        int qty = element['quantity'] is int ? element['quantity'] : int.parse(element['quantity'].toString());
        return sum + (price * qty);
      });
      
      // Keep rewards processing calculations beautifully synced
      if (_isPointsRedeemed) {
        _pointsDiscount = _userPoints;
      }
    });
  }

  // 🔑 HELPER: Dynamic logic handler to calculate realistic delivery values based on address location
  double _calculateDynamicDeliveryFee(String? address) {
    if (_selectedDeliveryMethod == "Self-Pickup") {
      return 0.0; // Self-pickup is completely free
    }
    
    if (address == null || address.trim().isEmpty || address == "No address selected") {
      return widget.deliveryFee;
    }

    String lowerAddress = address.toLowerCase();

    // If customer is from East Malaysia (Sabah/Sarawak), scale shipping realistically
    if (lowerAddress.contains("sabah") || lowerAddress.contains("sarawak") || lowerAddress.contains("labuan")) {
      return 15.00; 
    }
    
    // If customer is from deep Southern states like Johor or Melaka, prevent flat RM5 losses
    if (lowerAddress.contains("johor") || lowerAddress.contains("melaka") || lowerAddress.contains("malacca")) {
      return 12.00;
    }

    // Default standard local state delivery fee
    return widget.deliveryFee;
  }

  Future<String?> _recordDemandAnalytics(String outletName, double total) async {
    debugPrint("DEBUG: CheckoutPage - Saving Order to Firestore. Received outletId: ${widget.outletId}");

    if (user == null) return null;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      bool hasUpdates = false;

      // 🛠️ DATA NORMALIZATION: Keeps admin panel fields and manual fields completely unified
      List<Map<String, dynamic>> normalizedItems = [];

      for (var item in _localItems) {
        String? productId = item['id'] ?? item['productId'] ?? item['product_id'] ?? item['docId'];
        int purchasedQty = (item['quantity'] is int) ? item['quantity'] : (int.tryParse(item['quantity'].toString()) ?? 0);

        // Fallback structural safety nets to read keys used by your Admin Manage Products panel
        String finalName = item['name'] ?? item['productName'] ?? item['product_name'] ?? 'Product Item';
        double finalPrice = (item['price'] is num) ? item['price'].toDouble() : (double.tryParse(item['price'].toString()) ?? 0.0);
        String finalImage = item['image'] ?? item['imageUrl'] ?? item['productImage'] ?? '';

        if (productId != null && productId.toString().isNotEmpty && purchasedQty > 0) {
          // Add cleaned map that perfectly matches what your receipt overview lists read from
          normalizedItems.add({
            'id': productId.toString().trim(),
            'name': finalName,
            'price': finalPrice,
            'quantity': purchasedQty,
            'image': finalImage,
          });

          DocumentReference productRef = FirebaseFirestore.instance
              .collection('products')
              .doc(productId.toString().trim());
          
          batch.update(productRef, {
            'stock': FieldValue.increment(-purchasedQty),
          });
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }

      final CollectionReference ordersRef = FirebaseFirestore.instance.collection('orders');
      DocumentReference newOrderDocRef = ordersRef.doc();
      String generatedOrderId = newOrderDocRef.id;

      await newOrderDocRef.set({
        'productName': normalizedItems.isNotEmpty ? normalizedItems[0]['name'] : 'Multiple Items',
        'items': normalizedItems, // 🔑 Fixed: Saves unified fields so receipts load every item correctly
        'quantity': normalizedItems.length,
        'totalPrice': total,
        'outletId': widget.outletId,
        'outletName': outletName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'paid',
        'uid': user?.uid,
        'deliveryMethod': _selectedDeliveryMethod, // 🔑 Track if order is delivery or pickup
      });

      return generatedOrderId;
    } catch (e) {
      debugPrint("Firestore Error during checkout sync: $e");
      return null;
    }
  }

  void _showAddAddressDialog() {
    final TextEditingController addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Add Shipping Address", style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: addressController,
            decoration: const InputDecoration(
              hintText: "Enter your full delivery address",
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                String newAddress = addressController.text.trim();
                if (newAddress.isNotEmpty && user != null) {
                  try {
                    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
                    await userRef.update({
                      'addresses': FieldValue.arrayUnion([newAddress]),
                      'address': newAddress 
                    });

                    setState(() {
                      _selectedAddress = newAddress;
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Address saved and synchronized to your profile!")),
                    );
                  } catch (e) {
                    debugPrint("Error saving address to profile: $e");
                  }
                }
              },
              child: const Text("Save Address", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddressPicker(List<dynamic> addresses) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder( 
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Navigator.canPop(context) ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Select Shipping Address", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_location_alt, color: Colors.redAccent),
                        onPressed: () {
                          Navigator.pop(context);
                          _showAddAddressDialog();
                        },
                      )
                    ],
                  ) : const SizedBox(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: addresses.length,
                      itemBuilder: (context, index) {
                        return RadioListTile<String>(
                          activeColor: Colors.redAccent,
                          title: Text(addresses[index]),
                          value: addresses[index],
                          groupValue: _selectedAddress,
                          onChanged: (value) {
                            setState(() => _selectedAddress = value); 
                            setModalState(() {}); 
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );
    }

    final String displayName = _userData['name'] ?? "User";
    final List<dynamic> addresses = _userData['addresses'] ?? 
        (_userData['address'] != null ? [_userData['address']] : []);

    if (_selectedAddress == null && addresses.isNotEmpty) {
      _selectedAddress = addresses[0];
    }

    // 🔑 Dynamic assessment of active shipping cost tier matching rules
    double currentActiveDeliveryFee = _calculateDynamicDeliveryFee(_selectedAddress);

    // Dynamic point deduction update tracking helper using local updated totals
    double totalSummary = (_localSubtotal + currentActiveDeliveryFee) - _pointsDiscount;
    final String selectedOutlet = ModalRoute.of(context)?.settings.arguments as String? ?? "DesaMall Outlet";

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Checkout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // 🛠️ FIXED TYPO HERE
          children: [
            _buildHeader("Shipping Address"),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.redAccent),
                title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_selectedAddress ?? "No address selected"),
                trailing: TextButton(
                  onPressed: () {
                    if (addresses.isNotEmpty) {
                      _showAddressPicker(addresses);
                    } else {
                      _showAddAddressDialog();
                    }
                  }, 
                  child: Text(addresses.isNotEmpty ? "Change" : "Add"),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildHeader("Loyalty Rewards"),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.stars, color: Colors.amber),
                title: const Text("Redeem Reward Points", style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text("Available: RM ${_userPoints.toStringAsFixed(2)}", style: TextStyle(color: Colors.grey[600])),
                trailing: Switch.adaptive(
                  activeColor: Colors.redAccent,
                  value: _isPointsRedeemed,
                  onChanged: _userPoints > 0 
                      ? (bool value) {
                          setState(() {
                            _isPointsRedeemed = value;
                            _pointsDiscount = value ? _userPoints : 0.0;
                          });
                        }
                      : null, // Keeps the switch beautifully disabled if point balance is 0
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildHeader("Fulfilling Outlet"),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.storefront, color: Colors.redAccent),
                title: Text(selectedOutlet, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Items will be shipped from this branch"),
              ),
            ),

            const SizedBox(height: 20),

            _buildHeader("Review Items"),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _localItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 20, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final item = _localItems[index];
                    final double price = (item['price'] is num) ? item['price'].toDouble() : double.tryParse(item['price'].toString()) ?? 0.0;
                    final int quantity = item['quantity'] is int ? item['quantity'] : int.parse(item['quantity'].toString());
                    final String imagePath = item['image']?.toString() ?? item['imageUrl']?.toString() ?? "";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 📦 Premium E-Commerce Aspect Image Framework Frame Container
                          Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade100, width: 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Builder(
                                builder: (context) {
                                  if (imagePath.isEmpty) {
                                    return const Icon(Icons.shopping_bag_outlined, size: 28, color: Colors.grey);
                                  }
                                  try {
                                    if (imagePath.startsWith('http')) {
                                      return Image.network(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 24));
                                    }
                                    if (imagePath.startsWith('assets/')) {
                                      return Image.asset(imagePath, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported, size: 24));
                                    }
                                    
                                    // Base64 Multi-Format Decryption String Block Engine
                                    String cleanBase64 = imagePath.contains(',') ? imagePath.split(',').last : imagePath;
                                    return Image.memory(
                                      base64Decode(cleanBase64.trim()),
                                      fit: BoxFit.contain,
                                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                                    );
                                  } catch (e) {
                                    return const Icon(Icons.broken_image, size: 24, color: Colors.grey);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          
                          // Description & Info Column Label Details Block
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item['name'] ?? "Product",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "RM ${price.toStringAsFixed(2)}",
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                
                                // 🔄 Interactive E-Commerce Inline Counter Control Widget Row Box
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _updateItemQuantity(index, quantity - 1),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                        ),
                                        child: Icon(Icons.remove, size: 14, color: quantity <= 1 ? Colors.grey : Colors.black87),
                                      ),
                                    ),
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 32),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "$quantity",
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black87),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => _updateItemQuantity(index, quantity + 1),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                                        ),
                                        child: const Icon(Icons.add, size: 14, color: Colors.black87),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          
                          // Absolute aggregate product cost block layout
                          Text(
                            "RM ${(price * quantity).toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),
            
            _buildHeader("Payment Method"),
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: const ListTile(
                leading: Icon(Icons.qr_code_scanner),
                title: Text("QR Payment / Manual Receipt"),
              ),
            ),
            
            const SizedBox(height: 20),

            _buildHeader("Delivery Method"),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    activeColor: Colors.redAccent,
                    title: const Text("Courier Delivery (easyParcel)", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(_selectedAddress != null && _calculateDynamicDeliveryFee(_selectedAddress) > widget.deliveryFee 
                        ? "Cross-Regional Rate Adjustments Applied" 
                        : "Standard Regional Distribution Rate"),
                    value: "Delivery",
                    groupValue: _selectedDeliveryMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedDeliveryMethod = value!;
                      });
                    },
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  RadioListTile<String>(
                    activeColor: Colors.redAccent,
                    title: const Text("Self-Pickup at Outlet", style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text("Collect directly from your selected branch"),
                    value: "Self-Pickup",
                    groupValue: _selectedDeliveryMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedDeliveryMethod = value!;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _summaryRow("Order Subtotal", _localSubtotal),
                  if (_isPointsRedeemed && _pointsDiscount > 0) 
                    _summaryRow("Points Discount", -_pointsDiscount),
                  _summaryRow(_selectedDeliveryMethod == "Self-Pickup" ? "Self-Pickup Fee" : "Delivery Fee", currentActiveDeliveryFee),
                  const Divider(),
                  _summaryRow("Total Summary", totalSummary > 0 ? totalSummary : 0, isBold: true),
                ],
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () async {
                  if (_selectedDeliveryMethod == "Delivery" && 
                      (_selectedAddress == null || _selectedAddress!.trim().isEmpty || _selectedAddress == "No address selected")) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please add a shipping address before continuing!"),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  String? orderDocId = await _recordDemandAnalytics(selectedOutlet, totalSummary);

                  if (!mounted) return;

                  debugPrint("DEBUG: CheckoutPage - Navigating to PaymentPage. Passing outletId: ${widget.outletId}");

                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PaymentPage(
                        selectedAddress: _selectedDeliveryMethod == "Self-Pickup" ? "Self-Pickup at $selectedOutlet" : _selectedAddress,
                        totalAmount: totalSummary,
                        selectedOutlet: selectedOutlet, 
                        orderId: orderDocId,
                        outletId: widget.outletId,
                        isPointsRedeemed: _isPointsRedeemed,
                      ),
                    ),
                  );
                },
                child: const Text("CONTINUE WITH PAYMENT", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8.0),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("RM ${amount.toStringAsFixed(2)}", style: TextStyle(fontSize: isBold ? 18 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.redAccent : Colors.black)),
        ],
      ),
    );
  }
}