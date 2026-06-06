import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Standard Flutter package for formatting dates cleanly

class RewardsHistoryPage extends StatefulWidget {
  @override
  _RewardsHistoryPageState createState() => _RewardsHistoryPageState();
}

class _RewardsHistoryPageState extends State<RewardsHistoryPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🎯 Clean, standard function to fetch and combine reward records
  Future<List<Map<String, dynamic>>> _getCombinedRewards() async {
    if (user == null) return [];

    // 1. Fetch approved receipts
    final receiptsSnapshot = await FirebaseFirestore.instance
        .collection('receipts')
        .where('uid', isEqualTo: user!.uid)
        .where('status', isEqualTo: 'Approved')
        .get();

    // 2. Fetch rewards history log sub-collection
    final historySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('rewards_history')
        .get();

    Map<String, Map<String, dynamic>> consolidatedMap = {};

    // 3. Process old legacy approved items
    for (var doc in receiptsSnapshot.docs) {
      final data = doc.data();
      final double points = (data['points_earned'] ?? 0.0).toDouble();
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      
      if (points > 0) {
        consolidatedMap[doc.id] = {
          'title': 'Points Earned',
          'receipt_id': doc.id,
          'amount': points,
          'timestamp': ts,
        };
      }
    }

    // 4. Process new real-time log updates (overwrites duplicates gracefully)
    for (var doc in historySnapshot.docs) {
      final data = doc.data();
      final String receiptId = data['receipt_id'] ?? 'N/A';
      final double amount = (data['amount'] ?? 0.0).toDouble();
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      final String title = data['title'] ?? 'Points Updated';

      String uniqueKey = receiptId != 'N/A' && receiptId.isNotEmpty 
          ? "${receiptId}_${amount < 0 ? 'deduct' : 'earn'}" 
          : doc.id;

      consolidatedMap[uniqueKey] = {
        'title': title,
        'receipt_id': receiptId,
        'amount': amount,
        'timestamp': ts,
      };
    }

    // 5. Convert to list data array elements
    List<Map<String, dynamic>> finalList = consolidatedMap.values.toList();
    
    // Sort items by server timestamps chronologically descending
    finalList.sort((a, b) {
      Timestamp tA = a['timestamp'] ?? Timestamp.now();
      Timestamp tB = b['timestamp'] ?? Timestamp.now();
      return tB.compareTo(tA);
    });

    return finalList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Premium bright canvas backdrop
      appBar: AppBar(
        title: const Text("My Rewards", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTotalBalanceCard(),
          
          // 🎯 Modern E-Commerce Search Bar Layout Block
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toUpperCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search by receipt number...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.redAccent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(left: 20.0, right: 16.0, top: 16.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Rewards History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getCombinedRewards(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
                }

                var listItems = snapshot.data ?? [];

                // 🎯 Filter records out dynamically based on the current search text query parameters
                if (_searchQuery.isNotEmpty) {
                  listItems = listItems.where((item) {
                    final String receiptId = (item['receipt_id'] ?? '').toString().toUpperCase();
                    return receiptId.contains(_searchQuery);
                  }).toList();
                }

                if (listItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? "No matching receipts found." : "No rewards activity recorded yet.", 
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: listItems.length,
                  itemBuilder: (context, index) {
                    final item = listItems[index];
                    
                    final double amount = item['amount'];
                    final String title = item['title'];
                    final String receiptId = item['receipt_id'];
                    
                    // 🎯 Detailed & Clean Timestamp Formatting Breakdown Routine
                    String formattedDateTime = "Today";
                    if (item['timestamp'] != null) {
                      DateTime date = (item['timestamp'] as Timestamp).toDate();
                      formattedDateTime = DateFormat('yyyy-MM-dd • hh:mm a').format(date);
                    }

                    bool isDeduction = amount < 0;

                    // 🎯 Beautiful Digital Wallet E-Commerce Style Item Cards Layout
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.grey[100]!, width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isDeduction ? Colors.red[50] : Colors.amber[50],
                              child: Icon(
                                isDeduction ? Icons.remove_circle_outline_rounded : Icons.stars_rounded, 
                                color: isDeduction ? Colors.red : Colors.orange,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    receiptId != 'N/A' && receiptId.length >= 8
                                        ? "ID: ${receiptId.toUpperCase()}"
                                        : "ID: $receiptId",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDateTime, 
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDeduction ? Colors.red[50] : Colors.green[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${isDeduction ? '-' : '+'} RM ${amount.abs().toStringAsFixed(2)}", 
                                style: TextStyle(
                                  color: isDeduction ? Colors.red[700] : Colors.green[700], 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildTotalBalanceCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
      builder: (context, snapshot) {
        double currentBalance = 0.0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          currentBalance = (data['reward_points'] ?? 0.0).toDouble();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.redAccent, Colors.orangeAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.25), 
                blurRadius: 12, 
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(
            // 🎯 Fixed: Changed .between to .spaceBetween
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Available Balance", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    "RM ${currentBalance.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // 🎯 Fixed: Changed color parameter type variant format from white87
                  Text("Ready to save on your next order", style: TextStyle(color: Colors.white.withOpacity(0.87), fontSize: 11)),
                ],
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withOpacity(0.15),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
              )
            ],
          ),
        );
      },
    );
  }
}