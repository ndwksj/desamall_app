import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; 
import 'receipts_history_customer.dart'; 
import 'rewards_history_page.dart'; 
import 'change_password_screen.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  
  late DateTime _pageOpenTime;

  @override
  void initState() {
    super.initState();
    _pageOpenTime = DateTime.now(); 
    _startNotificationListener();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel(); 
    super.dispose();
  }

  void _showFloatingWarning(String message) {
    late OverlayEntry overlayEntry;
    
    overlayEntry = OverlayEntry(
      builder: (context) => _FloatingNotificationWidget(
        message: message,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  void _startNotificationListener() {
    if (user == null) return;
    try {
      _notificationSubscription = FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: user!.uid)
          .snapshots()
          .listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var data = change.doc.data() as Map<String, dynamic>;
            bool isRead = data['isRead'] ?? false;
            Timestamp? docTimestamp = data['timestamp'] as Timestamp?;
            
            if (!isRead && docTimestamp != null) {
              DateTime notificationTime = docTimestamp.toDate();
              if (notificationTime.isAfter(_pageOpenTime)) {
                _showTopNotificationPopup(
                  data['title'] ?? "Update", 
                  data['message'] ?? ""
                );
              }
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Listener Error: $e");
    }
  }

  void _showTopNotificationPopup(String title, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.75, left: 15, right: 15),
        backgroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Row(
          children: [
            Icon(
              title.contains('Approved') ? Icons.check_circle : Icons.notifications_active, 
              color: title.contains('Approved') ? Colors.green : Colors.redAccent
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  Text(message, style: const TextStyle(color: Colors.black87, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('notifications').where('recipientId', isEqualTo: user?.uid).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                  
                  List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
                  docs.sort((a, b) {
                    Timestamp t1 = a['timestamp'] ?? Timestamp.now();
                    Timestamp t2 = b['timestamp'] ?? Timestamp.now();
                    return t2.compareTo(t1);
                  });

                  if (docs.isEmpty) return const Center(child: Text("No updates yet.", style: TextStyle(color: Colors.grey)));
                  
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var note = docs[index];
                      bool isRead = note['isRead'] ?? false;
                      String title = note['title'] ?? "Update";
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: title.contains('Approved') ? Colors.green[50] : Colors.red[50],
                          child: Icon(title.contains('Approved') ? Icons.check_circle_outline : Icons.error_outline, color: title.contains('Approved') ? Colors.green : Colors.red),
                        ),
                        title: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(note['message'] ?? ""),
                        onTap: () => note.reference.update({'isRead': true}),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileSheet(String currentName, String? currentPhone, String? currentEmail, String? currentBase64) {
    TextEditingController nameEditController = TextEditingController(text: currentName);
    TextEditingController phoneEditController = TextEditingController(text: currentPhone ?? "");
    TextEditingController emailEditController = TextEditingController(text: currentEmail ?? user?.email ?? "");
    String? newBase64 = currentBase64;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: StatefulBuilder(
          builder: (context, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 15),
              const Text("Edit Profile", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 25),
              
              GestureDetector(
                onTap: () async {
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 300, imageQuality: 70);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setModalState(() => newBase64 = base64Encode(bytes));
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 3),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[100],
                        backgroundImage: newBase64 != null ? MemoryImage(base64Decode(newBase64!)) : null,
                        child: newBase64 == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                        child: const Icon(Icons.photo_camera_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text("Tap photo to change", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 25),
              
              TextField(
                controller: nameEditController, 
                decoration: InputDecoration(
                  labelText: "Full Name", 
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5))
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: emailEditController, 
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Email Address", 
                  prefixIcon: const Icon(Icons.mail_outline_rounded, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5))
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: phoneEditController, 
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number", 
                  prefixIcon: const Icon(Icons.phone_android_outlined, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5))
                ),
              ),
              const SizedBox(height: 25),
              
              SizedBox(
                width: double.infinity, 
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0
                  ),
                  onPressed: () async {
                    String newEmail = emailEditController.text.trim();
                    String newName = nameEditController.text.trim();
                    String newPhone = phoneEditController.text.trim();

                    try {
                      // 1. Update active Firebase Authentication profile email record if altered
                      if (user != null && newEmail != user!.email && newEmail.isNotEmpty) {
                        await user!.updateEmail(newEmail);
                      }

                      // 2. Synchronize details inside Cloud Firestore structure
                      await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({
                        'name': newName, 
                        'email': newEmail,
                        'phone': newPhone,
                        'profilePicture': newBase64
                      });

                      if (mounted) Navigator.pop(context);
                    } catch (error) {
                      // Handle re-authentication requirement if user hasn't logged in recently
                      debugPrint("Profile Update Error: $error");
                      _showFloatingWarning(error.toString().contains('requires-recent-login') 
                        ? "Please log out and log back in to verify your email change safely." 
                        : "Failed to save profile modifications.");
                    }
                  },
                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddressSheet({String? oldAddress, int? index, List? allAddresses}) {
    final streetController = TextEditingController();
    final cityController = TextEditingController();
    final stateController = TextEditingController();
    final postalCodeController = TextEditingController();

    // Parse the existing comma-separated address cleanly back into the new layout components
    if (oldAddress != null) {
      List<String> parts = oldAddress.split(',');
      if (parts.length >= 1) streetController.text = parts[0].trim();
      if (parts.length >= 2) {
        String postalAndCity = parts[1].trim();
        List<String> subParts = postalAndCity.split(' ');
        if (subParts.length >= 2) {
          postalCodeController.text = subParts[0].trim();
          cityController.text = subParts.sublist(1).join(' ').trim();
        } else {
          cityController.text = postalAndCity;
        }
      }
      if (parts.length >= 3) stateController.text = parts[2].trim();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 15),
              Text(oldAddress == null ? "Add New Address" : "Edit Address", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(height: 25),
              
              TextField(
                controller: streetController, 
                decoration: InputDecoration(
                  labelText: "Street Address", 
                  hintText: "Enter street details...",
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.7)))
                )
              ),
              const SizedBox(height: 14),
              
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityController, 
                      decoration: InputDecoration(
                        labelText: "City", 
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.7)))
                      )
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: postalCodeController, 
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Postal Code", 
                        border: const OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.7)))
                      )
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              
              TextField(
                controller: stateController, 
                decoration: InputDecoration(
                  labelText: "State / Province", 
                  border: const OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.7)))
                )
              ),
              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    String street = streetController.text.trim();
                    String city = cityController.text.trim();
                    String state = stateController.text.trim();
                    String postal = postalCodeController.text.trim();
                    
                    if (street.isEmpty || city.isEmpty || state.isEmpty || postal.isEmpty) {
                      _showFloatingWarning("Please fill up all address elements.");
                      return; 
                    }

                    // Format address text matching standard string synchronization matching your array pattern
                    String newAddr = "$street, $postal $city, $state";

                    List updatedList = List.from(allAddresses ?? []);
                    if (index != null) { updatedList[index] = newAddr; } else { updatedList.add(newAddr); }
                    await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'addresses': updatedList});
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Save Address", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int index, List allAddresses) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Address?"),
        content: const Text("Are you sure you want to remove this address?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              List updatedList = List.from(allAddresses);
              updatedList.removeAt(index);
              await FirebaseFirestore.instance.collection('users').doc(user?.uid).update({'addresses': updatedList});
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        title: const Text("My Profile", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.redAccent, 
        centerTitle: true, 
        elevation: 0,
        automaticallyImplyLeading: false, 
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('notifications').where('recipientId', isEqualTo: user?.uid).snapshots(),
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.docs.where((doc) => doc['isRead'] == false).length;
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26), onPressed: () => _showNotificationsPanel(context)),
                  if (unreadCount > 0) 
                    Positioned(
                      right: 6, 
                      top: 6, 
                      child: Container(
                        padding: const EdgeInsets.all(4), 
                        decoration: const BoxDecoration(
                          color: Colors.yellow, 
                          shape: BoxShape.circle
                        ), 
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? "9+" : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.black, 
                              fontSize: 9, 
                              fontWeight: FontWeight.bold,
                              height: 1.0
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          String name = "Customer";
          String? profileBase64;
          String? phone;
          String? email;
          List addresses = [];
          double rewardPoints = 0.0;
          if (snapshot.hasData && snapshot.data!.exists) {
            Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
            name = data['name'] ?? "Customer";
            profileBase64 = data['profilePicture'];
            phone = data['phone'];
            email = data['email'];
            addresses = data['addresses'] ?? [];
            rewardPoints = (data['reward_points'] ?? 0.0).toDouble();
          }

          // Read reactive email cleanly fallback sequence
          String verifiedEmailDisplay = (email != null && email.isNotEmpty) ? email : (user?.email ?? "");

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent, 
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32))
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 45),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _showEditProfileSheet(name, phone, verifiedEmailDisplay, profileBase64),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                              child: CircleAvatar(
                                radius: 38, 
                                backgroundColor: Colors.white24, 
                                backgroundImage: profileBase64 != null ? MemoryImage(base64Decode(profileBase64)) : null, 
                                child: profileBase64 == null ? const Icon(Icons.person, size: 45, color: Colors.white) : null
                              ),
                            ),
                            Positioned(
                              bottom: 0, 
                              right: 0, 
                              child: Container(
                                padding: const EdgeInsets.all(5), 
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), 
                                child: const Icon(Icons.edit_rounded, size: 12, color: Colors.redAccent)
                              )
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, 
                          children: [
                            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)), 
                            const SizedBox(height: 4),
                            Text(verifiedEmailDisplay, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w400)),
                            if (phone != null && phone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(phone, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w400)),
                            ],
                          ]
                        )
                      ),
                    ],
                  ),
                ),
                
                _buildRewardsDashboard(rewardPoints),
                _buildReceiptStatusCard(context),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(padding: EdgeInsets.only(left: 4, bottom: 12, top: 4), child: Text("ACCOUNT SETTINGS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 11, letterSpacing: 1.2))),
                      _buildSettingsTile(Icons.stars_rounded, "Rewards History", "Check earned points", () => Navigator.push(context, MaterialPageRoute(builder: (_) => RewardsHistoryPage()))),
                      _buildSettingsTile(Icons.lock_outline_rounded, "Change Password", "Update your security credentials", () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen()))),
                      _buildSettingsTile(Icons.notifications_none_outlined, "Notifications", "Check your recent updates", () => _showNotificationsPanel(context)),
                      _buildSettingsTile(Icons.security_outlined, "Privacy & Policy", "Our terms", () => _showInfoDialog("Privacy Policy", "Data secured.")),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          const Text("SHIPPING ADDRESSES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black45, fontSize: 11, letterSpacing: 1.2)), 
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () => _openAddressSheet(allAddresses: addresses), 
                            icon: const Icon(Icons.add, size: 16), 
                            label: const Text("Add New", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                          )
                        ]
                      ),
                      const SizedBox(height: 8),
                      if (addresses.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            children: [
                              Icon(Icons.location_on_outlined, size: 32, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text("No addresses saved yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                            ],
                          ),
                        ),
                      ...addresses.asMap().entries.map((entry) {
                        int idx = entry.key; 
                        String addr = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200)
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle), child: const Icon(Icons.home_filled, color: Colors.redAccent, size: 20)),
                            title: Text(addr, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500, height: 1.3)),
                            onTap: () => _openAddressSheet(oldAddress: addr, index: idx, allAddresses: addresses),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                  onPressed: () => _openAddressSheet(oldAddress: addr, index: idx, allAddresses: addresses),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                  onPressed: () => _showDeleteConfirmation(idx, addresses)
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                
                const SizedBox(height: 15),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async { await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushReplacementNamed(context, '/login'); }, 
                  icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18), 
                  label: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14))
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRewardsDashboard(double points) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C3E50), Color(0xFF3498DB)], 
            begin: Alignment.topLeft,
            end: Alignment.bottomRight
          ), 
          borderRadius: BorderRadius.circular(20), 
          boxShadow: [BoxShadow(color: const Color(0xFF2C3E50).withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text("REWARDS BALANCE", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)), 
                  const SizedBox(height: 4),
                  Text("RM ${points.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5))
                ]
              )
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RewardsHistoryPage())), 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF2C3E50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)), 
              child: const Text("History", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
            )
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptStatusCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200)
        ),
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              title: const Text("Order Tracking", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), 
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("View History", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.redAccent)
                ],
              ), 
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsHistoryCustomer(initialFilter: "All"))),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusIcon(Icons.hourglass_empty_rounded, "Pending", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsHistoryCustomer(initialFilter: "Pending")))),
                  _buildStatusIcon(Icons.check_circle_outline_rounded, "Approved", Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsHistoryCustomer(initialFilter: "Approved")))),
                  _buildStatusIcon(Icons.local_shipping_outlined, "Shipped", Colors.blueAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsHistoryCustomer(initialFilter: "Shipped")))),
                  _buildStatusIcon(Icons.cancel_outlined, "Rejected", Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReceiptsHistoryCustomer(initialFilter: "Rejected")))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap, 
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), 
            const SizedBox(height: 8), 
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700))
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.06), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.redAccent, size: 20)), 
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)), 
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)), 
        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey.shade400), 
        onTap: onTap
      ),
    );
  }
}

class _FloatingNotificationWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _FloatingNotificationWidget({required this.message, required this.onDismiss});

  @override
  __FloatingNotificationWidgetState createState() => __FloatingNotificationWidgetState();
}

class __FloatingNotificationWidgetState extends State<_FloatingNotificationWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: const Offset(0.0, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF323232),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 22),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}