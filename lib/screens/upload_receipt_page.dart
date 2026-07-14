import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import '../cart.dart'; 
import 'shipping_progress_page.dart';

class UploadReceiptPage extends StatefulWidget {
  final String? selectedAddress;
  final double? totalAmount;
  final String? selectedOutlet;
  final double? pointsEarned;
  final String? outletId;
  final String? orderId; // Added to receive the pre-generated Order Document ID string
  final bool isPointsRedeemed; // Added parameter to handle the balance clear execution logic safely

  UploadReceiptPage({
    Key? key, 
    this.selectedAddress, 
    required this.totalAmount, 
    this.selectedOutlet, 
    this.pointsEarned,
    this.outletId,
    this.orderId, // Added to constructor mapping setup
    this.isPointsRedeemed = false, // Instantiated default parameters safely
  }) : super(key: key);

  @override
  _UploadReceiptPageState createState() => _UploadReceiptPageState();
}

class _UploadReceiptPageState extends State<UploadReceiptPage> {
  File? _receiptFile;
  bool _isUploading = false;
  bool _isPdf = false;
  final ImagePicker _picker = ImagePicker();

  // Helper function to check file size limits
  bool _isValidSize(File file, int maxMb) {
    int sizeInBytes = file.lengthSync();
    double sizeInMb = sizeInBytes / (1024 * 1024);
    return sizeInMb <= maxMb;
  }

  // Helper function to check valid picture extensions (including PDF if picked via gallery)
  bool _isValidImageExtension(String path) {
    final allowedExtensions = ['jpeg', 'jpg', 'gif', 'png', 'tiff', 'bmp', 'pdf'];
    final extension = path.split('.').last.toLowerCase();
    return allowedExtensions.contains(extension);
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 25);
    if (pickedFile != null) {
      File file = File(pickedFile.path);

      // 1. Validate allowed image format variants
      if (!_isValidImageExtension(file.path)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid format! Only JPEG, JPG, GIF, PNG, TIFF, BMP, and PDF are accepted."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Validate file size does not exceed 10MB
      if (!_isValidSize(file, 10)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("File size exceeds the 10MB limit for pictures."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _receiptFile = file;
        // Mark as PDF if a PDF file was picked inside the gallery selection scope
        _isPdf = file.path.split('.').last.toLowerCase() == 'pdf';
      });
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);

      // 1. Double check extension structure explicitly
      if (file.path.split('.').last.toLowerCase() != 'pdf') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid format! Only PDF files are accepted here."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Validate file size does not exceed 5MB
      if (!_isValidSize(file, 5)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("File size exceeds the 5MB limit for PDFs."),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _receiptFile = file;
        _isPdf = true;
      });
    }
  }

  Future<void> _uploadAndProceed() async {
    String _mapNameToId(String name) {
      final Map<String, String> nameToId = {
        'DesaMall@Lipis': 'lipis',
        'DesaMall@Kepala Batas': 'kepala_batas',
        'Desamall@Ipoh': 'ipoh',
      };
      return nameToId[name] ?? name; // Fallback to original if not found
    }

    // Use it here before creating the data map
    String finalOutletId = _mapNameToId(widget.outletId ?? "");

    debugPrint("DEBUG: UploadReceiptPage - Received outletId: ${widget.outletId}");

    if (_receiptFile == null) return;
    setState(() => _isUploading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      List<int> fileBytes = await _receiptFile!.readAsBytes();
      String base64File = base64Encode(fileBytes);

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String userName = userDoc.exists ? (userDoc.data() as Map<String, dynamic>)['name'] ?? "Customer" : "Customer";

      // Fetch user's active point value before resetting it to 0
      double currentPointsBalance = userDoc.exists ? ((userDoc.data() as Map<String, dynamic>)['reward_points'] ?? 0.0).toDouble() : 0.0;

      // NEW RULE: Check for minimum spend floor of RM 100
      double amount = widget.totalAmount ?? 0.0;
      double calculatedPoints = amount > 100.0 ? amount * 0.005 : 0.0;

      // NEW METHOD DETECTOR: Intelligently identifies if the user chose self pickup
      bool isSelfPickup = widget.selectedAddress?.startsWith("Self-Pickup") ?? false;
      String deliveryMethod = isSelfPickup ? "Self-Pickup" : "Delivery";

      // Map out data packet parameters
      Map<String, dynamic> receiptData = {
        'uid': user.uid,
        'user_name': userName,
        'receipt_base64': base64File,
        'file_type': _isPdf ? 'pdf' : 'image',
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
        'shipping_address': widget.selectedAddress, 
        'total_price': widget.totalAmount,
        'points_earned': calculatedPoints,
        'outlet': widget.selectedOutlet ?? 'General',
        'outletId': finalOutletId, 
        'order_id': widget.orderId, 
        'delivery_method': deliveryMethod, // Synchronizes delivery method option to database
      };

      // If self-pickup is active, default tracking number parameter inside receipt layout
      if (isSelfPickup) {
        receiptData['tracking_number'] = "Self-Pickup";
      }

      // Set the receipt's Document ID to equal the Order's Document ID exactly
      if (widget.orderId != null && widget.orderId!.trim().isNotEmpty) {
        debugPrint("DEBUG: UploadReceiptPage - Saving to Firestore with finalOutletId: $finalOutletId");
        await FirebaseFirestore.instance
            .collection('receipts')
            .doc(widget.orderId!.trim())
            .set(receiptData);
      } else {
        await FirebaseFirestore.instance
            .collection('receipts')
            .add(receiptData);
      }

      // --- ATOMIC TRANSACTION BATCH FOR REWARDS HISTORY UPDATES ---
      WriteBatch rewardsBatch = FirebaseFirestore.instance.batch();
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      if (widget.isPointsRedeemed && currentPointsBalance > 0) {
        // 1. Reset user's points value field directly to 0.00 inside the database profile
        rewardsBatch.update(userRef, {'reward_points': 0.00});

        // 2. Add an elegant negative deduction item log to the sub-collection history instantly
        DocumentReference deductionLogRef = userRef.collection('rewards_history').doc();
        rewardsBatch.set(deductionLogRef, {
          'title': 'Points Redeemed',
          'receipt_id': widget.orderId ?? 'N/A',
          'amount': -currentPointsBalance, // Logged as negative value for explicit tracking UI layout
          'timestamp': FieldValue.serverTimestamp(),
        });
        debugPrint("DEBUG: User reward points reset to 0.00 and deduction logged.");
      }

      // 3. Log a record for the newly upcoming points that are pending verification
      DocumentReference earningLogRef = userRef.collection('rewards_history').doc();
      rewardsBatch.set(earningLogRef, {
        'title': 'Points Earned (Pending)',
        'receipt_id': widget.orderId ?? 'N/A',
        'amount': calculatedPoints, // Positive addition balance value
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Safely commit all points mutations and transaction tracking history logs together
      await rewardsBatch.commit();
      // -----------------------------------------------------------------

      WriteBatch batch = FirebaseFirestore.instance.batch();
      var cartItems = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cart')
          .get();

      for (var doc in cartItems.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      setState(() {
        cart.clear(); 
      });

      if (mounted) _showSuccessDialog();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessDialog() {
    double selectedRating = 0;
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 15),
                const Text("Payment Sent!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
                const SizedBox(height: 5),
                const Text("Your receipt is uploaded and your bag is cleared.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 25),
                const Divider(),
                const SizedBox(height: 15),
                const Text("How was your experience?", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      onPressed: () => setDialogState(() => selectedRating = index + 1.0),
                      icon: Icon(
                        index < selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 38,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: feedbackController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Tell us more...",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(15),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: () async {
  if (selectedRating > 0) {
    // Now including the required fields for dashboard to show
    await FirebaseFirestore.instance.collection('reviews').add({
      'rating': selectedRating,
      'feedback': feedbackController.text,
      'timestamp': FieldValue.serverTimestamp(),
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'outletId': widget.outletId ?? 'all', // Ensure this is mapped to your ID
      'month': DateTime.now().month,
      'year': DateTime.now().year,
    });
  }
  if (mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ShippingProgressPage(
          address: widget.selectedAddress,
          total: widget.totalAmount,
          currentStatus: "Pending",
          outletId: widget.outletId,
          outletName: widget.selectedOutlet,
        )
      ),
    );
  }
},
                  child: const Text("SUBMIT FEEDBACK & VIEW MY SHIPPING", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/home', 
                    (route) => false,
                    arguments: {
                      'id': widget.outletId ?? "",
                      'name': widget.selectedOutlet ?? "DesaMall Outlet",
                    },
                  ),
                  child: const Text("Back to Home", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //  Dynamically update top panel indicator headers
    bool isSelfPickup = widget.selectedAddress?.startsWith("Self-Pickup") ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Upload Receipt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text("Total: RM ${widget.totalAmount?.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    isSelfPickup 
                        ? "Pickup at: ${widget.selectedAddress ?? 'Not specified'}"
                        : "Deliver to: ${widget.selectedAddress ?? 'Not specified'}", 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 300, width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[400]!)),
              child: _receiptFile == null
                  ? Icon(Icons.receipt_long, size: 100, color: Colors.grey[400])
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12), 
                      child: _isPdf 
                        ? Center(child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.picture_as_pdf, size: 80, color: Colors.redAccent),
                              const SizedBox(height: 10),
                              Text(_receiptFile!.path.split('/').last, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ))
                        : Image.file(_receiptFile!, fit: BoxFit.cover)
                    ),
            ),
            const SizedBox(height: 30),
            if (_isUploading) const CircularProgressIndicator(color: Colors.redAccent)
            else ...[
              ElevatedButton.icon(
                onPressed: _pickPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("UPLOAD PDF"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text("GALLERY"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text("CAMERA"),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
              ),
              if (_receiptFile != null) ...[
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _uploadAndProceed,
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: const Text("CONFIRM & PROCEED"),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}