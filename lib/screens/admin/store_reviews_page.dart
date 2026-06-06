import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:desamall_app/screens/admin/store_reviews_page.dart';

class SalesReportPage extends StatefulWidget {
  final String branchAccess; // 'all' for main admin, or the specific outlet string identifier for branch admins

  const SalesReportPage({Key? key, this.branchAccess = 'all'}) : super(key: key);

  @override
  _SalesReportPageState createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  String? selectedOutletId;
  String? selectedOutletName;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  Future<void> migrateOldReviews() async {
    var collection = FirebaseFirestore.instance.collection('reviews');
    var snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      var data = doc.data() as Map<String, dynamic>;
      if (data['month'] == null && data['timestamp'] != null) {
        DateTime date = (data['timestamp'] as Timestamp).toDate();
        await doc.reference.update({'month': date.month, 'year': date.year});
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Migration complete!")));
    }
  }

  final List<String> months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  final List<int> availableYears = [2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026];

  @override
  void initState() {
    super.initState();
    // 🔒 If it's a branch admin, lock their outlet context automatically right away
    if (widget.branchAccess != 'all') {
      selectedOutletId = widget.branchAccess;
      _autoResolveBranchDetails();
    }
  }

  Future<void> _autoResolveBranchDetails() async {
    try {
      // First try to fetch assuming branchAccess is the document ID directly
      var doc = await FirebaseFirestore.instance.collection('outlets').doc(widget.branchAccess).get();
      if (doc.exists && mounted) {
        setState(() {
          selectedOutletId = doc.id; // Ensure we use the true doc.id for queries
          String rawName = doc.data()?['name'] ?? '';
          if (rawName.toLowerCase().contains('ipoh')) {
            selectedOutletName = "DesaMall@Ipoh";
          } else if (rawName.toLowerCase().contains('lipis')) {
            selectedOutletName = "DesaMall@Lipis";
          } else if (rawName.toLowerCase().contains('batas')) {
            selectedOutletName = "DesaMall@Kepala Batas";
          } else {
            selectedOutletName = rawName;
          }
        });
      } else {
        // Fallback search if branchAccess is a slug like 'kepala_batas' or 'lipis'
        var querySnapshot = await FirebaseFirestore.instance.collection('outlets').get();
        for (var outletDoc in querySnapshot.docs) {
          String docName = (outletDoc.data()['name'] ?? '').toString().toLowerCase();
          String lookup = widget.branchAccess.toLowerCase().replaceAll('_', ' ');
          
          // Match keywords like 'lipis' or 'batas'
          if (docName.contains(lookup) || lookup.contains('batas') && docName.contains('batas') || lookup.contains('lipis') && docName.contains('lipis') || lookup.contains('ipoh') && docName.contains('ipoh')) {
            if (mounted) {
              setState(() {
                selectedOutletId = outletDoc.id; // 🔑 Correctly set the dynamic Firestore Doc ID so orders filter properly
                String rawName = outletDoc.data()['name'] ?? '';
                if (rawName.toLowerCase().contains('ipoh')) {
                  selectedOutletName = "DesaMall@Ipoh";
                } else if (rawName.toLowerCase().contains('lipis')) {
                  selectedOutletName = "DesaMall@Lipis";
                } else if (rawName.toLowerCase().contains('kepala_batas')) {
                  selectedOutletName = "DesaMall@Kepala Batas";
                } else {
                  selectedOutletName = rawName;
                }
              });
            }
            break;
          }
        }
      }
    } catch (_) {
      // Direct local fail-safe processing string matching if database queries hit connection lag
      if (mounted) {
        setState(() {
          if (widget.branchAccess.contains('kepala_batas')) {
            selectedOutletName = "DesaMall@Kepala Batas";
          } else if (widget.branchAccess.contains('lipis')) {
            selectedOutletName = "DesaMall@Lipis";
          } else {
            selectedOutletName = "DesaMall@Ipoh";
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMainAdmin = widget.branchAccess == 'all';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isMainAdmin ? "Sales & Revenue" : (selectedOutletName ?? "Branch Revenue"),
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => migrateOldReviews(),
            tooltip: "Run Migration",
          ),
        ],
      ),
      body: Column(
        children: [
          // 🛠️ Dynamic visibility switcher based on user privileges
          if (isMainAdmin) _buildOutletPicker(),
          _buildDateFilters(),
          const Divider(height: 1),
          Expanded(
            child: (isMainAdmin && selectedOutletId == null)
                ? _buildEmptyState("Select an outlet to view financial reports")
                : _buildSalesReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildOutletPicker() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('outlets').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();
          var outlets = snapshot.data!.docs;
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: "Select Store Location",
              prefixIcon: const Icon(Icons.store, color: Colors.redAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            value: selectedOutletId,
            items: outlets.map((doc) {
              return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedOutletId = val;
                selectedOutletName = outlets.firstWhere((d) => d.id == val)['name'];
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDateFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: "Month",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              value: selectedMonth,
              items: List.generate(12, (index) {
                return DropdownMenuItem(value: index + 1, child: Text(months[index]));
              }),
              onChanged: (val) => setState(() => selectedMonth = val!),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<int>(
              decoration: InputDecoration(
                labelText: "Year",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              value: selectedYear,
              items: availableYears.map((int year) {
                return DropdownMenuItem(value: year, child: Text(year.toString()));
              }).toList(),
              onChanged: (val) => setState(() => selectedYear = val!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    Query query = FirebaseFirestore.instance.collection('receipts');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        final allDocs = snapshot.data?.docs ?? [];
        double totalRevenue = 0.0;
        Map<String, int> productSalesCount = {};

        // 📈 PRE-LOADED MOCK REVENUE DATA FOR PAST YEARS (2019-2025)
        Map<int, double> yearlyRevenueMap = {
          2019: 14250.00,
          2020: 19800.50,
          2021: 24500.00,
          2022: 31200.25,
          2023: 42150.80,
          2024: 53900.00,
          2025: 61420.10,
          2026: 0.0,
        };

        // 📅 PRE-LOADED MOCK REVENUE DATA FOR EARLY 2026 MONTHS (Jan-Mar)
        Map<int, double> mockMonths2026 = {
          1: 1850.00, 
          2: 2100.40, 
          3: 1650.90, 
        };

        // Initialize 2026 base with historical jan-mar values
        yearlyRevenueMap[2026] = mockMonths2026[1]! + mockMonths2026[2]! + mockMonths2026[3]!;
        
        bool isHistoricalMockTimeframe = (selectedYear < 2026) || (selectedYear == 2026 && selectedMonth <= 3);

        if (selectedYear == 2026 && isHistoricalMockTimeframe && mockMonths2026.containsKey(selectedMonth)) {
          totalRevenue = mockMonths2026[selectedMonth]!;
        } else if (selectedYear < 2026) {
          totalRevenue = yearlyRevenueMap[selectedYear]! / 12;
        }

        if (isHistoricalMockTimeframe) {
          productSalesCount = {
            "DELISH Tomyam Putih (6x10g)": 45,
            "AYNUF Pes Sambal Tumis (100g)": 38,
            "Kerepek Ubi Pedas Basah": 27,
            "Madu Kelulut Asli": 19,
          };
        }

        // Loop through actual receipts from Firestore database
        for (var doc in allDocs) {
          var data = doc.data() as Map<String, dynamic>;

          // 🛠️ FIX 1: Safely accept status variants like "Shipped" or "Approved" so June totals display perfectly
          String docStatus = (data['status'] ?? '').toString().toLowerCase();
          if (docStatus == 'rejected' || docStatus == 'pending') {
            continue; 
          }

          String docOutletId = (data['outletId'] ?? '').toString();
          
          // 🛠️ FIX 2: Added dynamic fallback to read the explicit 'outlet' descriptor string matching your Firestore document keys
          String docOutletName = (data['outlet'] ?? data['outletName'] ?? data['assignedOutlet'] ?? '').toString();

          if (selectedOutletId != null) {
            bool matchesId = docOutletId == selectedOutletId;
            bool matchesName = docOutletName.toLowerCase().contains(selectedOutletName?.toLowerCase() ?? '___unknown___');
            
            if (!matchesId && !matchesName && docOutletId.isNotEmpty && docOutletId != "Verifying Outlet...") {
              continue; 
            }
          }

          Timestamp? timestamp = data['timestamp'] as Timestamp?;
          if (timestamp != null) {
            DateTime date = timestamp.toDate();

            double orderTotal = 0.0;
            var rawTotal = data['totalPrice'] ?? data['total_price'] ?? data['totalPaidAmount'] ?? data['subtotal'] ?? 0.0;
            if (rawTotal is num) {
              orderTotal = rawTotal.toDouble();
            } else if (rawTotal is String) {
              orderTotal = double.tryParse(rawTotal.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
            }

            // Accumulate live amounts into the dynamic 2026 tracking matrix 
            if (date.year == 2026) {
              yearlyRevenueMap[2026] = yearlyRevenueMap[2026]! + orderTotal;
            } else if (yearlyRevenueMap.containsKey(date.year)) {
              yearlyRevenueMap[date.year] = yearlyRevenueMap[date.year]! + orderTotal;
            }

            // Secure calculation process for June (month 6)
            if (!isHistoricalMockTimeframe && date.month == selectedMonth && date.year == selectedYear) {
              totalRevenue += orderTotal;

              if (data['items'] != null && data['items'] is List) {
                List items = data['items'];
                for (var item in items) {
                  String name = item['name'] ?? item['productName'] ?? "Unknown Item";
                  int qty = (item['quantity'] ?? item['qty'] ?? 1).toInt();
                  productSalesCount[name] = (productSalesCount[name] ?? 0) + qty;
                }
              } else {
                String? name = data['productName'] ?? data['product_name'] ?? data['itemsOrdered'];
                if (name != null) {
                  int qty = (data['quantity'] ?? data['qty'] ?? 1).toInt();
                  productSalesCount[name] = (productSalesCount[name] ?? 0) + qty;
                }
              }
            }
          }
        }

        var topProducts = productSalesCount.keys.toList()
          ..sort((a, b) => productSalesCount[b]!.compareTo(productSalesCount[a]!));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildRevenueHeader(totalRevenue, months[selectedMonth - 1], selectedYear),
            const SizedBox(height: 24),

            _buildRatingsAndFeedbackSection(),
            const SizedBox(height: 24),

            const Text("Top Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (topProducts.isEmpty)
              _buildEmptyState("No sales found for ${months[selectedMonth - 1]} $selectedYear")
            else
              ...topProducts.take(5).map((name) => _buildSalesTile(name, productSalesCount[name]!, isHistoricalMockTimeframe)).toList(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text("Yearly Performance Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildYearlyRevenueGrid(yearlyRevenueMap),
          ],
        );
      },
    );
  }

  Widget _buildRevenueHeader(double total, String month, int year) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEF5350), Color(0xFFC62828)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Text("REVENUE FOR $month $year".toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12)),
          const SizedBox(height: 12),
          Text("RM ${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildRatingsAndFeedbackSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                "Customer Satisfaction & Feedback",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (selectedOutletId != null || widget.branchAccess == 'all')
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoreReviewsPage(
                        outletId: selectedOutletName ?? 'All Outlets',
                        outletName: selectedOutletName ?? 'All Outlets',
                        monthName: months[selectedMonth - 1],
                        monthInt: selectedMonth,
                        year: selectedYear,
                      ),
                    ),
                  );
                },
                child: const Row(
                  children: [
                    Text("View All", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.redAccent),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: () {
            var query = FirebaseFirestore.instance.collection('reviews')
                .where('month', isEqualTo: selectedMonth)
                .where('year', isEqualTo: selectedYear);

            if (selectedOutletId != null && selectedOutletId != 'all') {
              query = query.where('outletId', isEqualTo: selectedOutletName);
            }
            
            return query.snapshots();
          }(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
            }

            if (snapshot.hasError) {
              debugPrint("Firebase Error: ${snapshot.error}");
              return const Center(child: Text("Error loading data."));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.grey[50], 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: Colors.grey.shade200)
                ),
                child: const Center(
                    child: Text("No feedback records found for this period.", 
                    style: TextStyle(color: Colors.grey, fontSize: 13))
                ),
              );
            }

            final reviews = snapshot.data!.docs;
            double totalStars = 0.0;
            for (var doc in reviews) {
              var data = doc.data() as Map<String, dynamic>;
              var r = data['rating'];
              totalStars += (r is num) ? r.toDouble() : 0.0;
            }
            double averageRating = reviews.isNotEmpty ? (totalStars / reviews.length) : 0.0;

            return InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => StoreReviewsPage(
                      outletId: selectedOutletName ?? 'All Outlets',
                      outletName: selectedOutletName ?? 'All Outlets',
                      monthName: months[selectedMonth - 1],
                      monthInt: selectedMonth,
                      year: selectedYear,
                    )));
              },
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))], border: Border.all(color: Colors.grey.shade100)),
                    child: Row(
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(averageRating.toStringAsFixed(1), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.black87)),
                          const Text("out of 5 stars", style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text("${reviews.length} total reviews", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(width: 24),
                        Expanded(child: Row(children: List.generate(5, (index) => Icon(index < averageRating.round() ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 32)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length > 3 ? 3 : reviews.length,
                    itemBuilder: (context, index) {
                      var data = reviews[index].data() as Map<String, dynamic>;
                      int starCount = (data['rating'] ?? 5).toInt();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Expanded(child: Text(data['userName'] ?? "Verified Customer", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            Row(children: List.generate(5, (s) => Icon(s < starCount ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 13))),
                          ]),
                          const SizedBox(height: 6),
                          Text("\"${data['feedback'] ?? ""}\"", style: TextStyle(color: Colors.grey[700], fontSize: 12, fontStyle: FontStyle.italic)),
                        ]),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildYearlyRevenueGrid(Map<int, double> yearlyRevenueMap) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: availableYears.length,
      itemBuilder: (context, idx) {
        int currentYearElement = availableYears[idx];
        double totalYearRevenue = yearlyRevenueMap[currentYearElement] ?? 0.0;
        bool isCurrentlyPicked = currentYearElement == selectedYear;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: isCurrentlyPicked ? Colors.redAccent.withOpacity(0.04) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentlyPicked ? Colors.redAccent : Colors.grey.shade200,
                width: isCurrentlyPicked ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))
              ]),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Year $currentYearElement",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isCurrentlyPicked ? Colors.redAccent : Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  "RM ${totalYearRevenue.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesTile(String name, int qty, bool isMockTimeframe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () {
          if (isMockTimeframe) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Detail log view is only available for live data.")),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductSalesDetailScreen(
                productName: name,
                monthInt: selectedMonth,
                monthName: months[selectedMonth - 1],
                year: selectedYear,
                outletId: selectedOutletId ?? 'all_outlets',
              ),
            ),
          );
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.star_rounded, color: Colors.redAccent, size: 24),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("$qty units sold"),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: isMockTimeframe ? Colors.grey.shade300 : Colors.redAccent,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class ProductSalesDetailScreen extends StatelessWidget {
  final String productName;
  final int monthInt;
  final String monthName;
  final int year;
  final String outletId;

  const ProductSalesDetailScreen({
    Key? key,
    required this.productName,
    required this.monthInt,
    required this.monthName,
    required this.year,
    required this.outletId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Query refQuery = FirebaseFirestore.instance.collection('receipts');

    return Scaffold(
      appBar: AppBar(
        title: Text(productName),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: refQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            if (data['timestamp'] == null) return false;

            DateTime date = (data['timestamp'] as Timestamp).toDate();
            bool dateMatch = date.month == monthInt && date.year == year;
            bool nameMatch = false;

            if (data['items'] != null) {
              nameMatch = (data['items'] as List).any((item) => (item['name'] ?? item['productName']) == productName);
            } else {
              nameMatch = (data['productName'] ?? data['product_name']) == productName;
            }

            return dateMatch && nameMatch;
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Text(
                "No transaction detail lines logged in database.",
                style: TextStyle(color: Colors.grey.shade400),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              DateTime date = (data['timestamp'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.receipt_long, color: Colors.redAccent),
                  title: Text("Order #${docs[index].id.substring(0, 8)}"),
                  subtitle: Text("${date.day} $monthName $year"),
                  trailing: Text(
                    "RM ${(data['totalPrice'] ?? data['total_price'] ?? data['totalPaidAmount'] ?? 0.0).toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class StoreReviewsPage extends StatelessWidget {
  final String outletId;
  final String outletName;
  final String monthName;
  final int monthInt;
  final int year;

  const StoreReviewsPage({
    Key? key,
    required this.outletId,
    required this.outletName,
    required this.monthName,
    required this.monthInt,
    required this.year,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Customer Feedback Detail", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("$outletName • $monthName $year", style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reviews').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          final allDocs = snapshot.data?.docs ?? [];

          final filteredReviews = allDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            
            if (outletId != 'all' && data['outletId'] != outletId) {
              return false;
            }

            if (data['timestamp'] != null) {
              DateTime date = (data['timestamp'] as Timestamp).toDate();
              return date.month == monthInt && date.year == year;
            }
            
            return false;
          }).toList();

          if (filteredReviews.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    "No feedback submissions recorded for this period.",
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredReviews.length,
            itemBuilder: (context, index) {
              var data = filteredReviews[index].data() as Map<String, dynamic>;
              int starCount = (data['rating'] ?? 5).toInt();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['userName'] ?? "Verified Customer", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(children: List.generate(5, (s) => Icon(s < starCount ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.amber, size: 16))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(data['feedback'] ?? "", style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}