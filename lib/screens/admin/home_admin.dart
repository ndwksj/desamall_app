import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:desamall_app/screens/admin/outlet_details_admin.dart';
import 'package:desamall_app/screens/admin/products_admin.dart';
import 'package:desamall_app/screens/admin/profile_admin.dart';
import 'package:desamall_app/screens/admin/receipts_admin.dart';
import 'package:desamall_app/screens/admin/manage_users_page.dart'; 

class HomeAdmin extends StatefulWidget {
  @override
  _HomeAdminState createState() => _HomeAdminState();
}

class _HomeAdminState extends State<HomeAdmin> {
  int _selectedIndex = 0;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  String _adminRole = 'admin';
  String _branchAccess = 'all';
  List<String> _matchedOutletDocIds = []; 
  bool _isLoadingRole = true;

  // Store stable stream references in state memory
  Stream<QuerySnapshot>? _badgeStream;
  Stream<DocumentSnapshot>? _profileCardStream;
  Stream<QuerySnapshot>? _outletsHorizontalStream;
  Stream<QuerySnapshot>? _productsHorizontalStream;

  @override
  void initState() {
    super.initState();
    _loadAdminRoleData();
  }

  @override
  void dispose() {
    _badgeStream = null;
    _profileCardStream = null;
    _outletsHorizontalStream = null;
    _productsHorizontalStream = null;
    super.dispose();
  }

  Future<void> _loadAdminRoleData() async {
    if (currentUser != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(currentUser!.uid)
            .get();
            
        if (!mounted) return;

        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          String branchText = (data['branchAccess'] ?? 'all').toString().trim();
          
          List<String> matchedIds = [];

          if (branchText != 'all') {
            var allOutlets = await FirebaseFirestore.instance
                .collection('outlets')
                .limit(50)
                .get();
            
            print("--- DESAMALL DEBUGGING LOGS ---");
            print("Admin branchAccess string is: '$branchText'");
            
            for (var outletDoc in allOutlets.docs) {
              var outletData = outletDoc.data();
              String oId = (outletData['outletId'] ?? '').toString().trim();
              String oName = (outletData['name'] ?? '').toString().toLowerCase();
              
              print("Checking Store Document ID: ${outletDoc.id} | field outletId: '$oId' | Name: '$oName'");

              if (oId == branchText || 
                  outletDoc.id == branchText || 
                  oId.replaceAll('_', '').replaceAll('-', '') == branchText.replaceAll('_', '').replaceAll('-', '') ||
                  oName.contains(branchText.replaceAll('_', ' '))) {
                matchedIds.add(outletDoc.id);
              }
            }
            print("Total matched outlet items found: ${matchedIds.length}");
            print("---------------------------------");
          }

          if (mounted) {
            setState(() {
              _adminRole = data['role'] ?? 'admin';
              _branchAccess = branchText;
              _matchedOutletDocIds = matchedIds;
              _isLoadingRole = false;
              // Initialize query configurations immediately after context resolves
              _prepareDataStreams();
            });
          }
          return;
        }
      } catch (e) {
        debugPrint("Error loading admin privileges: $e");
      }
    }
    if (mounted) {
      setState(() {
        _isLoadingRole = false;
        _prepareDataStreams();
      });
    }
  }

  // Instantiates the listeners once to completely eliminate UI micro-stutters
  void _prepareDataStreams() {
    // 1. Orders badge counter stream setup
    Query pendingQuery = FirebaseFirestore.instance
        .collection('receipts')
        .where('status', isEqualTo: 'Pending');
    if (_branchAccess != 'all') {
      pendingQuery = pendingQuery.where('outletId', isEqualTo: _branchAccess);
    }
    _badgeStream = pendingQuery.snapshots();

    // 2. Main banner user profile name display stream setup
    if (currentUser != null) {
      _profileCardStream = FirebaseFirestore.instance
          .collection('admins')
          .doc(currentUser!.uid)
          .snapshots();
    }

    // 3. Operational Outlets horizontal scroll query setup
    Query outletQuery = FirebaseFirestore.instance.collection('outlets').limit(10);
    if (_branchAccess != 'all' && _matchedOutletDocIds.isNotEmpty) {
      outletQuery = FirebaseFirestore.instance.collection('outlets').where(FieldPath.documentId, whereIn: _matchedOutletDocIds).limit(10);
    } else if (_branchAccess != 'all') {
      outletQuery = FirebaseFirestore.instance.collection('outlets').where('outletId', isEqualTo: _branchAccess).limit(10);
    }
    _outletsHorizontalStream = outletQuery.snapshots();

    // 4. Product catalog horizontal scroll query setup
    Query productQuery = FirebaseFirestore.instance.collection('products').limit(15);
    if (_branchAccess != 'all') {
      List<String> lookups = [_branchAccess];
      if (_matchedOutletDocIds.isNotEmpty) {
        lookups.addAll(_matchedOutletDocIds);
      }
      productQuery = FirebaseFirestore.instance.collection('products').where('outletId', arrayContainsAny: lookups).limit(15);
    }
    _productsHorizontalStream = productQuery.snapshots();
  }

  Widget _buildProductImage(String? path, {double? width, double? height}) {
    if (path == null || path.isEmpty) {
      return Container(
        color: const Color(0xFFF9F9F9),
        width: width, height: height,
        child: const Icon(Icons.image_outlined, color: Color(0xFFD2D7DB), size: 28),
      );
    }
    if (path.startsWith('http')) {
      return Image.network(path, width: width, height: height, fit: BoxFit.cover, 
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Color(0xFFD2D7DB)));
    }
    if (path.startsWith('assets/')) {
      return Image.asset(path, width: width, height: height, fit: BoxFit.cover);
    }
    try {
      return Image.memory(
        base64Decode(path.contains(',') ? path.split(',').last : path),
        width: width, height: height, fit: BoxFit.cover,
        cacheWidth: 300,
        cacheHeight: 300,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Color(0xFFD2D7DB)),
      );
    } catch (e) {
      return const Icon(Icons.broken_image, color: Color(0xFFD2D7DB));
    }
  }

  Widget _buildReceiptsBadgeIcon(bool isSelected) {
    // Fallback if role credentials processing isn't done yet
    if (_badgeStream == null) {
      return Icon(isSelected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined, size: 22);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _badgeStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Icon(isSelected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined, size: 22);
        }

        final count = snapshot.data!.docs.length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(isSelected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined, size: 22),
            Positioned(
              right: -6, top: -5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildDashboardView(context),
      ProductsAdmin(
        branchAccess: _branchAccess,
        onBackToDashboard: () {
          if (mounted) setState(() => _selectedIndex = 0);
        },
      ),
      ReceiptsAdmin(branchAccess: _branchAccess),
      ProfileAdmin(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: _selectedIndex == 1 
          ? null 
          : AppBar(
              title: const Text(
                "WORKSPACE MANAGER", 
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, fontSize: 16)
              ),
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFB71C1C)], 
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ),
              ),
              centerTitle: true,
              elevation: 0,
              automaticallyImplyLeading: false, 
              leading: _selectedIndex != 0 
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
                    onPressed: () {
                      if (mounted) setState(() => _selectedIndex = 0);
                    },
                  ) 
                : null,
            ),
      body: _isLoadingRole 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
          : IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE8ECEF), width: 1))),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            if (mounted) setState(() => _selectedIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: const Color(0xFFD32F2F), 
          unselectedItemColor: const Color(0xFF8A94A6),
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined, size: 22), activeIcon: Icon(Icons.dashboard_rounded, size: 22), label: "Workspace"),
            const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined, size: 22), activeIcon: Icon(Icons.inventory_2_rounded, size: 22), label: "Catalog"),
            BottomNavigationBarItem(icon: _buildReceiptsBadgeIcon(_selectedIndex == 2), label: "Orders"),
            const BottomNavigationBarItem(icon: Icon(Icons.manage_accounts_outlined, size: 22), activeIcon: Icon(Icons.manage_accounts_rounded, size: 22), label: "Account"),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardView(BuildContext context) {
    bool isMainAdmin = (_branchAccess == 'all');

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              colors: [Color(0xFF2C3E50), Color(0xFF1F2A38)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: DecorationImage(
                image: const AssetImage("assets/desamall.png"),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(const Color(0xFFD32F2F).withOpacity(0.35), BlendMode.darken),
              ),
            ),
            padding: const EdgeInsets.all(28),
            child: _profileCardStream == null
              ? const SizedBox(height: 64, child: Center(child: CircularProgressIndicator(color: Colors.white)))
              : StreamBuilder<DocumentSnapshot>(
                  stream: _profileCardStream,
                  builder: (context, snapshot) {
                    String name = (snapshot.hasData && snapshot.data!.exists) ? snapshot.data!['name'] : "Systems Admin";
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isMainAdmin ? "GLOBAL HUB" : "BRANCH ACCESS",
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                        const SizedBox(height: 4),
                        Text("Main Admin Administration", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    );
                  },
                ),
          ),
        ),
        const SizedBox(height: 32),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("System Operations", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2A38), letterSpacing: 0.2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isMainAdmin) ...[
                    _buildActionBtn(Icons.add_business_rounded, "New Outlet", _showAddOutletDialog),
                    const SizedBox(width: 12),
                  ],
                  _buildActionBtn(Icons.assignment_add, "New Product", _showAddProductDialog),
                  if (isMainAdmin) ...[
                    const SizedBox(width: 12),
                    _buildActionBtn(Icons.admin_panel_settings_rounded, "Manage Admins", () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersPage()));
                    }),
                  ],
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        _buildSectionHeader(isMainAdmin ? "Operational Outlets" : "Assigned Workspace Hub", () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OutletsManagementPage(branchAccess: _branchAccess, matchedDocIds: _matchedOutletDocIds)));
        }),
        _buildHorizontalOutlets(),
        const SizedBox(height: 32),
        _buildSectionHeader("Recent Catalog Feed", () {
          if (mounted) setState(() => _selectedIndex = 1); 
        }),
        _buildHorizontalProducts(),
      ],
    );
  }

  Widget _buildHorizontalOutlets() {
    if (_outletsHorizontalStream == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));

    return SizedBox(
      height: 180,
      child: StreamBuilder<QuerySnapshot>(
        stream: _outletsHorizontalStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No linked outlets.", style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13, fontWeight: FontWeight.w600)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => OutletDetailsAdmin(outlet: data, docId: docs[index].id)
                  ));
                },
                child: Container(
                  width: 240,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildProductImage(data['image']),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 14, left: 16, right: 16,
                          child: Text(data['name'] ?? "No Name", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHorizontalProducts() {
    if (_productsHorizontalStream == null) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));

    return SizedBox(
      height: 220,
      child: StreamBuilder<QuerySnapshot>(
        stream: _productsHorizontalStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          var docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("No items listed.", style: TextStyle(color: Color(0xFF8A94A6), fontSize: 13)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            scrollDirection: Axis.horizontal,
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var p = docs[index].data() as Map<String, dynamic>;
              return Container(
                width: 145,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                        child: Container(
                          width: double.infinity,
                          color: const Color(0xFFFAFAFA),
                          child: _buildProductImage(p['imageUrl']),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 12, right: 12),
                      child: Text(p['name'] ?? "", style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1F2A38)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 4),
                      child: Text("RM ${p['price']}", style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13, fontWeight: FontWeight.w800)),
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

  Widget _buildSectionHeader(String title, VoidCallback onAction) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1F2A38), letterSpacing: 0.2)),
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text("View All", style: TextStyle(color: Color(0xFFD32F2F), fontWeight: FontWeight.w800, fontSize: 12)),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFFD32F2F)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFD32F2F), size: 22),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF4A5568))),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    if (mounted) setState(() => _selectedIndex = 1); 
  }

  void _showAddOutletDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final uniqueIdController = TextEditingController(); 
    String? base64Image;
    bool isSaving = false;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Register System Outlet", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                if (isSaving)
                  const Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
                else ...[
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25, maxWidth: 400, maxHeight: 400);
                      if (pickedFile != null) {
                        final bytes = await File(pickedFile.path).readAsBytes();
                        if (context.mounted) {
                          setDialogState(() => base64Image = base64Encode(bytes));
                        }
                      }
                    },
                    child: Container(
                      height: 125, width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
                      ),
                      child: (base64Image != null)
                          ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.memory(base64Decode(base64Image!), fit: BoxFit.cover))
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF8A94A6), size: 32),
                                SizedBox(height: 6),
                                Text("Upload Cover Photo", style: TextStyle(color: Color(0xFF4A5568), fontSize: 11, fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController, 
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Outlet Name", 
                      labelStyle: const TextStyle(color: Color(0xFF8A94A6), fontSize: 13),
                      prefixIcon: const Icon(Icons.storefront, color: Color(0xFFD32F2F), size: 18),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8ECEF))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2))
                    )
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: uniqueIdController, 
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Identifier code (e.g. lipis, ipoh)", 
                      labelStyle: const TextStyle(color: Color(0xFF8A94A6), fontSize: 13),
                      prefixIcon: const Icon(Icons.vpn_key_rounded, color: Color(0xFFD32F2F), size: 18),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8ECEF))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2))
                    )
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: addressController, 
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      labelText: "Full Location Address", 
                      labelStyle: const TextStyle(color: Color(0xFF8A94A6), fontSize: 13),
                      prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFFD32F2F), size: 18),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8ECEF))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.2))
                    )
                  ),
                ]
              ],
            ),
          ),
          actions: isSaving ? [] : [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                if (nameController.text.isEmpty || uniqueIdController.text.isEmpty || base64Image == null) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all details including Outlet ID")));
                   return;
                }
                setDialogState(() => isSaving = true);
                try {
                  await FirebaseFirestore.instance.collection('outlets').add({
                    'name': nameController.text.trim(), 
                    'outletId': uniqueIdController.text.trim().toLowerCase(),
                    'address': addressController.text.trim(), 
                    'image': base64Image 
                  });
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Outlet Created successfully!"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (context.mounted) {
                    setDialogState(() => isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Operations Failed")));
                  }
                }
              }, 
              child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
            ),
          ],
        ),
      ),
    );
  }
}

class OutletsManagementPage extends StatelessWidget {
  final String branchAccess;
  final List<String> matchedDocIds;

  OutletsManagementPage({this.branchAccess = 'all', this.matchedDocIds = const []});

  Widget _buildRowImage(String? path) {
    if (path == null || path.isEmpty) {
      return Container(
        color: const Color(0xFFF9F9F9),
        width: 60, height: 60,
        child: const Icon(Icons.storefront, color: Color(0xFFD2D7DB), size: 24),
      );
    }
    try {
      return Image.memory(
        base64Decode(path.contains(',') ? path.split(',').last : path),
        width: 60, height: 60, fit: BoxFit.cover,
        cacheWidth: 150,
        cacheHeight: 150,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Color(0xFFD2D7DB)),
      );
    } catch (_) {
      return const Icon(Icons.broken_image, color: Color(0xFFD2D7DB));
    }
  }

  @override
  Widget build(BuildContext context) {
    Query outletQuery = FirebaseFirestore.instance.collection('outlets');
    if (branchAccess != 'all') {
      if (matchedDocIds.isNotEmpty) {
        outletQuery = outletQuery.where(FieldPath.documentId, whereIn: matchedDocIds);
      } else {
        outletQuery = outletQuery.where('outletId', isEqualTo: branchAccess);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text("Manage Outlets", style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15)),
        backgroundColor: const Color(0xFFD32F2F),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: outletQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
          final docs = snapshot.data!.docs;
          
          if (docs.isEmpty) {
            return const Center(child: Text("No outlets found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8ECEF)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildRowImage(data['image']),
                  ),
                  title: Text(data['name'] ?? "No Name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(data['address'] ?? "No Address listed", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => OutletDetailsAdmin(outlet: data, docId: docs[index].id)
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}