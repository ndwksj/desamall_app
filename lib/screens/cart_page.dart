import 'package:flutter/material.dart';
import 'dart:convert'; 
import '../cart.dart'; 
import 'checkout_page.dart';
import 'home_screen.dart';

class CartPage extends StatefulWidget {
  final String? selectedOutlet; 
  final String outletId;         

  const CartPage({
    Key? key, 
    this.selectedOutlet, 
    required this.outletId
  }) : super(key: key);

  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  
  void _incrementQuantity(Map item) {
    int maxStock = 0;
    if (item["stock"] != null) {
      maxStock = (item["stock"] is String) ? (int.tryParse(item["stock"]) ?? 0) : (item["stock"] as num).toInt();
    }

    if (maxStock > 0 && item["quantity"] >= maxStock) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cannot add more. Only $maxStock units available in stock.")),
      );
      return; 
    }

    setState(() {
      item["quantity"]++;
    });
  }

  void _decrementQuantity(Map item) {
    if (item["quantity"] > 1) {
      setState(() {
        item["quantity"]--;
      });
    } else {
      _confirmDeleteItem(item["name"]);
    }
  }

  void _confirmDeleteItem(String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Remove Item?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove $itemName from your bag?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                removeItem(itemName); 
              });
              Navigator.pop(context);
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmClearBag() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Bag?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("This will remove all items for this outlet. Continue?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              setState(() {
                cart.removeWhere((item) => item['outletId'] == widget.outletId);
              });
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Bag cleared for this outlet.")),
              );
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchItems = getCartItemsByOutlet(widget.outletId);
    double total = getTotal(widget.outletId);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        title: Text(
          widget.selectedOutlet ?? "My Bag", 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.5)
        ),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(outletId: widget.outletId),
                settings: RouteSettings(
                  arguments: {'id': widget.outletId, 'name': widget.selectedOutlet}
                ),
              ),
              (route) => false,
            );
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          if (branchItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
              onPressed: _confirmClearBag,
            )
        ],
      ),
      body: branchItems.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: branchItems.length,
              itemBuilder: (context, index) {
                final item = branchItems[index];
                return _buildCartItem(item);
              },
            ),
      bottomNavigationBar: branchItems.isEmpty ? null : _buildBottomCheckout(total, branchItems),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.redAccent.withOpacity(0.2)),
          ),
          const SizedBox(height: 20),
          Text(
            "Your bag is empty", 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            "Looks like you haven't added anything\nfrom ${widget.selectedOutlet ?? 'this outlet'} yet.", 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(Map item) {
    int maxStock = 0;
    if (item["stock"] != null) {
      maxStock = (item["stock"] is String) ? (int.tryParse(item["stock"]) ?? 0) : (item["stock"] as num).toInt();
    }
    
    // 🔒 Turns true instantly if quantity hits the maximum stock
    bool isMaxReached = maxStock > 0 && item["quantity"] >= maxStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 18), 
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25), 
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Builder(
              builder: (context) {
                final String path = item["image"]?.toString() ?? "";
                if (path.isEmpty) {
                  return Container(
                    width: 90, height: 90, 
                    color: Colors.grey[100], 
                    child: const Icon(Icons.image, color: Colors.grey)
                  );
                }
                try {
                  if (path.startsWith('http')) {
                    return Image.network(path, width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image));
                  }
                  if (path.startsWith('assets/')) {
                    return Image.asset(
                      path, 
                      width: 90, height: 90, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => 
                        Container(width: 90, height: 90, color: Colors.grey[100], child: const Icon(Icons.image, color: Colors.grey)),
                    );
                  }
                  
                  // Decodes administrative Base64 image payload strings safely and natively 
                  String cleanBase64 = path.contains(',') ? path.split(',').last : path;
                  return Image.memory(
                    base64Decode(cleanBase64.trim()),
                    width: 90, height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(width: 90, height: 90, color: Colors.grey[100], child: const Icon(Icons.broken_image, color: Colors.grey)),
                  );
                } catch (e) {
                  return Container(width: 90, height: 90, color: Colors.grey[100], child: const Icon(Icons.broken_image, color: Colors.grey));
                }
              },
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item["name"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("RM ${item["price"].toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _quantityButton(Icons.remove, () => _decrementQuantity(item), isDisabled: false),
                    Container(
                      constraints: const BoxConstraints(minWidth: 40),
                      alignment: Alignment.center,
                      child: Text("${item["quantity"]}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                    // 🎨 Button turns grey automatically if isDisabled is true
                    _quantityButton(Icons.add, () => _incrementQuantity(item), isDisabled: isMaxReached),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              radius: 18,
              child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            ),
            onPressed: () => _confirmDeleteItem(item["name"]),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckout(double total, List branchItems) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 25, offset: const Offset(0, -10))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Payment", style: TextStyle(fontSize: 15, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              Text("RM ${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 8,
                shadowColor: Colors.redAccent.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () {
                // ADD THIS LINE HERE
                debugPrint("DEBUG: CartPage - Selected Outlet ID: ${widget.selectedOutlet}");
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutPage(
                      items: List.from(branchItems), 
                      subtotal: total,
                      outletId: widget.selectedOutlet ?? "General",
                    ),
                    settings: RouteSettings(arguments: widget.selectedOutlet),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("PROCEED TO CHECKOUT", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8)),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityButton(IconData icon, VoidCallback onTap, {required bool isDisabled}) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDisabled ? Colors.grey[200] : Colors.white, // Turns grey background
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDisabled ? Colors.grey.shade400 : Colors.grey.shade400, width: 1.5),
        ),
        child: Icon(icon, size: 16, color: isDisabled ? Colors.grey.shade500 : Colors.black87), // Dimmed icon
      ),
    );
  }
}