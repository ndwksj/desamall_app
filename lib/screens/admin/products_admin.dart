import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart'; 

class ProductsAdmin extends StatefulWidget {
  final String? outletId;
  final String branchAccess; 
  final VoidCallback? onBackToDashboard; 

  const ProductsAdmin({
    Key? key, 
    this.outletId, 
    this.branchAccess = 'all',
    this.onBackToDashboard, 
  }) : super(key: key);

  @override
  _ProductsAdminState createState() => _ProductsAdminState();
}

class _ProductsAdminState extends State<ProductsAdmin> {
  String? selectedOutletId;
  String? selectedOutletName;
  String? currentScannedBarcode; 
  bool _isLoadingBranch = false;
  
  // Search parameters
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  final List<String> categories = [
    "Beverages", 
    "Cooking essentials", 
    "Food Supplements",
    "Gardening", 
    "Home care supplies", 
    "Nursery Page", 
    "Snacks"
  ];

  @override
  void initState() {
    super.initState();
    _setupRoutingContext();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _setupRoutingContext() async {
    if (widget.branchAccess != 'all') {
      setState(() => _isLoadingBranch = true);
      try {
        String lookupTarget = widget.branchAccess.trim();
        var doc = await FirebaseFirestore.instance.collection('outlets').doc(lookupTarget).get();
        if (doc.exists) {
          setState(() {
            selectedOutletId = lookupTarget;
            selectedOutletName = doc.data()?['name'] ?? lookupTarget;
          });
        } else {
          var allOutlets = await FirebaseFirestore.instance.collection('outlets').get();
          bool matchFound = false;

          for (var outletDoc in allOutlets.docs) {
            var outletData = outletDoc.data();
            String oId = (outletData['outletId'] ?? '').toString().trim();
            String oName = (outletData['name'] ?? '').toString().toLowerCase();

            if (oId == lookupTarget || 
                outletDoc.id == lookupTarget || 
                oId.replaceAll('_', '').replaceAll('-', '') == lookupTarget.replaceAll('_', '').replaceAll('-', '') ||
                oName.contains(lookupTarget.replaceAll('_', ' '))) {
              
              setState(() {
                selectedOutletId = outletDoc.id;
                selectedOutletName = outletData['name'] ?? lookupTarget;
              });
              matchFound = true;
              break;
            }
          }

          if (!matchFound) {
            setState(() {
              selectedOutletId = lookupTarget;
              selectedOutletName = lookupTarget;
            });
          }
        }
      } catch (e) {
        debugPrint("Error resolving branch mapping: $e");
      } finally {
        setState(() => _isLoadingBranch = false);
      }
    } else {
      setState(() {
        selectedOutletId = widget.outletId;
      });
    }
  }
  
  Future<void> _handleBarcodeScan(Function setDialogState, TextEditingController nameC, TextEditingController priceC, Function(String?) updateImage) async {
    var res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SimpleBarcodeScannerPage(),
        ));

    if (res is String && res != '-1') {
      currentScannedBarcode = res;
      
      // 🔑 THE OMNI-QUERY DYNAMIC FIX: First query main 'products' collection by field attributes
      var productQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: res)
          .limit(1)
          .get();

      if (productQuery.docs.isNotEmpty) {
        var data = productQuery.docs.first.data();
        setDialogState(() {
          nameC.text = data['name'] ?? "";
          priceC.text = data['price']?.toString() ?? "";
          updateImage(data['imageUrl']);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product details found in store database!"), backgroundColor: Colors.black87));
      } else {
        // Fallback structural check to secondary products_master reference logs
        var doc = await FirebaseFirestore.instance.collection('products_master').doc(res).get();

        if (doc.exists) {
          var data = doc.data()!;
          setDialogState(() {
            nameC.text = data['name'] ?? "";
            priceC.text = data['price']?.toString() ?? "";
            updateImage(data['imageUrl']);
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Local product found! Details filled."), backgroundColor: Colors.black87));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("New Barcode: $res. Please enter details manually."), backgroundColor: Colors.black87));
        }
      }
    }
  }

  void _confirmDelete(BuildContext context, DocumentReference ref, String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Product?", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16)),
        content: Text("Are you sure you want to delete '$productName'? This action cannot be undone.", style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await ref.delete();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("$productName has been deleted."),
                  backgroundColor: const Color(0xFFD32F2F),
                ));
              }
            }, 
            child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA), 
      appBar: AppBar(
        title: _isSearching 
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "Search products...",
                  hintStyle: TextStyle(color: Colors.white70, fontSize: 15),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              )
            : const Text(
                "STOCK MANAGER", 
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, fontSize: 15)
              ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFB71C1C)], 
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white),
          onPressed: () {
            if (_isSearching) {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _searchQuery = "";
              });
            } else {
              if (widget.onBackToDashboard != null) {
                widget.onBackToDashboard!(); 
              } else {
                Navigator.of(context).pop(); 
              }
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, size: 22, color: Colors.white),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _searchQuery = "";
                }
                _isSearching = !_isSearching;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingBranch 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)))
        : Column(
            children: [
              if (widget.branchAccess == 'all') _buildOutletDropdown(),
              Expanded(
                child: selectedOutletId == null
                    ? _buildEmptyState("Select an outlet location to manage stock")
                    : _buildProductStream(),
              ),
            ],
          ),
      floatingActionButton: selectedOutletId != null 
        ? FloatingActionButton.extended(
            backgroundColor: const Color(0xFFD32F2F), 
            elevation: 0,
            icon: const Icon(Icons.add_box_rounded, color: Colors.white),
            label: const Text("ADD PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            onPressed: () {
              currentScannedBarcode = null; 
              _showProductDialog(context);
            },
          )
        : null,
    );
  }

  Widget _buildOutletDropdown() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('outlets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator(color: Color(0xFFD32F2F));
          var outlets = snapshot.data!.docs;
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "Store Location",
              labelStyle: const TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
              prefixIcon: const Icon(Icons.storefront_rounded, color: Color(0xFFD32F2F)), 
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFE8ECEF), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5), 
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            value: selectedOutletId,
            items: outlets.map((doc) {
              return DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? "", style: const TextStyle(color: Color(0xFF1F2A38))));
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedOutletId = val;
                var selectedDoc = outlets.firstWhere((d) => d.id == val);
                selectedOutletName = selectedDoc['name'];
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildProductStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('outletId', arrayContains: selectedOutletId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFD32F2F)));
        var docs = snapshot.data?.docs ?? [];
        
        // Dynamic search filter across labels, categories, and prices
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String name = (data['name'] ?? "").toString().toLowerCase();
            String cat = (data['category'] ?? "General").toString().toLowerCase();
            String price = (data['price'] ?? "").toString().toLowerCase();
            return name.contains(_searchQuery) || cat.contains(_searchQuery) || price.contains(_searchQuery);
          }).toList();
        }

        if (docs.isEmpty) {
          return _buildEmptyState(_searchQuery.isNotEmpty 
              ? "No products match your search query." 
              : "No stock items registered for ${selectedOutletName ?? 'this branch'}");
        }

        Map<String, List<DocumentSnapshot>> groupedProducts = {};
        for (var doc in docs) {
          String cat = doc['category'] ?? "General";
          groupedProducts.putIfAbsent(cat, () => []).add(doc);
        }

        var sortedCategories = groupedProducts.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sortedCategories.length,
          itemBuilder: (context, index) {
            String categoryName = sortedCategories[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: _searchQuery.isNotEmpty, // Keep expanded during search matching
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE), 
                    child: Icon(Icons.inventory_2_rounded, color: Color(0xFFD32F2F), size: 18),
                  ),
                  title: Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1F2A38))),
                  subtitle: Text("${groupedProducts[categoryName]!.length} items managed", style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6))),
                  children: groupedProducts[categoryName]!.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    int stock = (data['stock'] ?? 0).toInt();

                    return Container(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F3F5)))),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: const Color(0xFFF8F9FA)),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _displayProductImage(data['imageUrl'] ?? ""),
                          ),
                        ),
                        title: Text(
                          data['name'] ?? "Product Item", 
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1F2A38), fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Text("RM ${data['price']}", style: const TextStyle(color: Color(0xFF1F2A38), fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: stock >= 5 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Stock: $stock", 
                                  style: TextStyle(color: stock >= 5 ? Colors.green[700] : const Color(0xFFB71C1C), fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 24), onPressed: () => _showProductDialog(context, doc: doc)),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD32F2F), size: 20), onPressed: () => _confirmDelete(context, doc.reference, data['name'] ?? "")),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProductDialog(BuildContext context, {DocumentSnapshot? doc}) {
    Map<String, dynamic>? data = doc?.data() as Map<String, dynamic>?;
    final nameC = TextEditingController(text: data?['name'] ?? "");
    final priceC = TextEditingController(text: data?['price']?.toString() ?? "");
    final stockC = TextEditingController(text: (data?['stock'] ?? 0).toInt().toString());
    
    String catFromDb = data?['category'] ?? categories[0];
    String selectedCategory = categories.contains(catFromDb) ? catFromDb : categories[0];
    String? existingImageUrl = data?['imageUrl'];
    bool isUploading = false;
    
    bool showErrorBanner = false; 
    String errorMessage = ""; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                doc == null ? "Register New Product" : "Edit Stock Item",
                style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1F2A38), fontSize: 16)
              ),
              if (doc == null) 
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFFD32F2F)),
                  onPressed: () => _handleBarcodeScan(
                    setDialogState, 
                    nameC, 
                    priceC, 
                    (newImg) => setDialogState(() => existingImageUrl = newImg)
                  ),
                )
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showErrorBanner)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD32F2F).withOpacity(0.3)),
                    ),
                    child: Text(
                      errorMessage, 
                      style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                GestureDetector(
                  onTap: () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);
                    if (pickedFile != null) {
                      final bytes = await File(pickedFile.path).readAsBytes();
                      setDialogState(() => existingImageUrl = base64Encode(bytes));
                    }
                  },
                  child: Container(
                    height: 130, width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8ECEF), width: 1.2),
                    ),
                    child: (existingImageUrl != null && existingImageUrl!.isNotEmpty)
                        ? ClipRRect(borderRadius: BorderRadius.circular(11), child: _displayProductImage(existingImageUrl!))
                        : const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF8A94A6)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true, 
                  value: selectedCategory,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Category Identification", 
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF1F2A38))))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedCategory = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameC, 
                  style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    labelText: "Product Label Name", 
                    labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                  )
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceC, 
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Price RM", 
                          labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                        )
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: stockC, 
                        style: const TextStyle(fontSize: 14, color: Color(0xFF1F2A38), fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Stock Units", 
                          labelStyle: TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD32F2F), width: 1.5))
                        )
                      )
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context), 
              child: const Text("Cancel", style: TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w700))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F), 
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
              ),
              onPressed: isUploading ? null : () async {
                if (nameC.text.isEmpty || priceC.text.isEmpty) return;

                double enteredPrice = double.tryParse(priceC.text) ?? 0.0;
                int enteredStock = int.tryParse(stockC.text) ?? 0;

                if (enteredPrice < 0.0 && enteredStock < 0) {
                  setDialogState(() {
                    showErrorBanner = true;
                    errorMessage = "Price and Stock cannot be negative numbers!";
                  });
                  return;
                } else if (enteredPrice < 0.0) {
                  setDialogState(() {
                    showErrorBanner = true;
                    errorMessage = "Price cannot be a negative number!";
                  });
                  return;
                } else if (enteredStock < 0) {
                  setDialogState(() {
                    showErrorBanner = true;
                    errorMessage = "Stock cannot be a negative number!";
                  });
                  return;
                }

                setDialogState(() => isUploading = true);
                try {
                  List<String> outletList = [selectedOutletId!];
                  
                  var commonData = {
                    'name': nameC.text.trim(),
                    'price': enteredPrice,
                    'imageUrl': existingImageUrl ?? "",
                    'category': selectedCategory, 
                  };

                  if (doc == null) {
                    await FirebaseFirestore.instance.collection('products').add({
                      ...commonData,
                      'stock': enteredStock,
                      'outletId': outletList,
                      'barcode': currentScannedBarcode,
                      "timestamp": FieldValue.serverTimestamp(),
                    });

                    if (currentScannedBarcode != null) {
                      await FirebaseFirestore.instance
                          .collection('products_master')
                          .doc(currentScannedBarcode)
                          .set(commonData);
                    }
                  } else {
                    await doc.reference.update({
                      ...commonData,
                      'stock': enteredStock,
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                } finally { 
                  if (context.mounted) setDialogState(() => isUploading = false);
                }
              },
              child: isUploading 
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Text(doc == null ? "Save" : "Update", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _displayProductImage(String imageUrl) {
    if (imageUrl.isEmpty) return const Icon(Icons.image_outlined, size: 22, color: Color(0xFF8A94A6));
    try {
      if (imageUrl.startsWith('assets/')) return Image.asset(imageUrl, fit: BoxFit.cover);
      String clean = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
      return Image.memory(base64Decode(clean), fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.broken_image));
    } catch (e) { return const Icon(Icons.broken_image); }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFD2D7DB)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF8A94A6), fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}