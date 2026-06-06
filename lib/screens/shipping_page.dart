import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_status_page.dart'; 

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;

  void _openAddressSheet({String? oldAddress, int? index, List? allAddresses}) {
    TextEditingController addressController = TextEditingController(text: oldAddress);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(oldAddress == null ? "Add New Address" : "Edit Address", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Enter full address..."),
              maxLines: 3,
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  String newAddr = addressController.text.trim();
                  if (newAddr.isEmpty) return;

                  List updatedList = List.from(allAddresses ?? []);
                  if (index != null) {
                    updatedList[index] = newAddr;
                  } else {
                    updatedList.add(newAddr);
                  }

                  await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                    'addresses': updatedList,
                  });

                  Navigator.pop(context);
                },
                child: const Text("Save Address", style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index, List allAddresses) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Address?"),
        content: const Text("Are you sure you want to remove this address?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              List updatedList = List.from(allAddresses);
              updatedList.removeAt(index);

              await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                'addresses': updatedList,
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Address deleted successfully")),
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String name = "Customer";
          List addresses = [];
          
          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Customer";
            addresses = data['addresses'] ?? (data['address'] != null ? [data['address']] : []);
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                  child: Row(
                    children: [
                      const CircleAvatar(radius: 40, backgroundColor: Colors.white, child: Icon(Icons.person, size: 50, color: Colors.redAccent)),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text(user?.email ?? "", style: const TextStyle(color: Colors.white70)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOrderCard(context),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 8),
                        child: Text("Account Settings", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      _buildSettingsTile(Icons.notifications_none_outlined, "Notifications", "Manage alerts", () {
                        _showInfoDialog("Notifications", "You are subscribed to all updates.");
                      }),
                      _buildSettingsTile(Icons.security_outlined, "Privacy & Policy", "Our terms", () {
                        _showInfoDialog("Privacy Policy", "Your data is secured with Firebase.");
                      }),
                      _buildSettingsTile(Icons.help_outline, "Help Centre", "FAQ & Support", () {
                        _showInfoDialog("Help Centre", "Support: support@desamall.com");
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Shipping Addresses", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          TextButton.icon(
                            onPressed: () => _openAddressSheet(allAddresses: addresses),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text("Add New"),
                          ),
                        ],
                      ),
                      if (addresses.isEmpty)
                        const Card(
                          child: ListTile(title: Text("No addresses saved.", style: TextStyle(fontSize: 14, color: Colors.grey))),
                        ),
                      ...addresses.asMap().entries.map((entry) {
                        int idx = entry.key;
                        String addr = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.home_outlined, color: Colors.redAccent),
                            title: Text("Address ${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(addr, style: const TextStyle(fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                  onPressed: () => _openAddressSheet(oldAddress: addr, index: idx, allAddresses: addresses),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                  onPressed: () => _showDeleteConfirmation(idx, addresses),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: TextButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text("Logout Account", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            ListTile(
              title: const Text("My Purchases", style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Text("View History", style: TextStyle(color: Colors.blue, fontSize: 12)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusPage())),
            ),
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOrderIcon(Icons.account_balance_wallet_outlined, "To Pay", () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusPage(filterStatus: "Unpaid")));
                  }),
                  _buildOrderIcon(Icons.local_shipping_outlined, "To Ship", () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusPage(filterStatus: "Pending")));
                  }),
                  _buildOrderIcon(Icons.inventory_2_outlined, "To Receive", () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderStatusPage(filterStatus: "Approved")));
                  }),
                  _buildOrderIcon(Icons.star_outline, "To Rate", () {
                    _showInfoDialog("Rate Feature", "The rating system is coming soon! Thank you for your patience.");
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[700], size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.redAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
