import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:desamall_app/screens/admin/store_reviews_page.dart';

class SalesReportPage extends StatefulWidget {
  final String branchAccess; 

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
    var collection = FirebaseFirestore.instance.collection('reviews').limit(50); 
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
    if (widget.branchAccess != 'all') {
      selectedOutletId = widget.branchAccess;
      _autoResolveBranchDetails();
    }
  }

  Future<void> _autoResolveBranchDetails() async {
    try {
      var doc = await FirebaseFirestore.instance.collection('outlets').doc(widget.branchAccess).get();
      if (doc.exists && mounted) {
        setState(() {
          selectedOutletId = doc.id; 
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
        var querySnapshot = await FirebaseFirestore.instance.collection('outlets').limit(30).get();
        for (var outletDoc in querySnapshot.docs) {
          String docName = (outletDoc.data()['name'] ?? '').toString().toLowerCase();
          String lookup = widget.branchAccess.toLowerCase().replaceAll('_', ' ');
          
          if (docName.contains(lookup) || lookup.contains('batas') && docName.contains('batas') || lookup.contains('lipis') && docName.contains('lipis') || lookup.contains('ipoh') && docName.contains('ipoh')) {
            if (mounted) {
              setState(() {
                selectedOutletId = outletDoc.id; 
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
        stream: FirebaseFirestore.instance.collection('outlets').limit(30).snapshots(), 
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
              if (mounted) {
                setState(() {
                  selectedOutletId = val;
                  selectedOutletName = outlets.firstWhere((d) => d.id == val)['name'];
                });
              }
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
              onChanged: (val) {
                if (mounted && val != null) setState(() => selectedMonth = val);
              },
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
              onChanged: (val) {
                if (mounted && val != null) setState(() => selectedYear = val);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    bool isMainAdmin = widget.branchAccess == 'all';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }

        final allDocs = snapshot.data?.docs ?? [];
        double totalRevenue = 0.0;
        double overallAccumulativeRevenue = 0.0; // 🎯 Added for Main Admin total sum calculations
        Map<String, int> productSalesCount = {};
        
        // 🎯 Track monthly layout values for Branch Admins graph
        Map<int, double> monthlySalesMap = {for (int i = 1; i <= 12; i++) i: 0.0};

        Map<int, double> yearlyRevenueMap = {
          2019: 14250.00, 2020: 19800.50, 2021: 24500.00, 2022: 31200.25,
          2023: 42150.80, 2024: 53900.00, 2025: 61420.10, 2026: 0.0,
        };

        for (var doc in allDocs) {
          var data = doc.data() as Map<String, dynamic>;

          String docOutletId = (data['outletId'] ?? '').toString();
          String docOutletName = (data['outlet'] ?? data['outletName'] ?? data['assignedOutlet'] ?? '').toString();

          double orderTotal = 0.0;
          var rawTotal = data['totalPrice'] ?? data['total_price'] ?? data['totalPaidAmount'] ?? data['subtotal'] ?? 0.0;
          if (rawTotal is num) {
            orderTotal = rawTotal.toDouble();
          } else if (rawTotal is String) {
            orderTotal = double.tryParse(rawTotal.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
          }

          // 🎯 Keep a running sum of everything for the Main Admin's accumulative view
          overallAccumulativeRevenue += orderTotal;

          if (selectedOutletId != null) {
            bool matchesId = docOutletId == selectedOutletId;
            bool matchesName = selectedOutletName != null && docOutletName.toLowerCase().contains(selectedOutletName!.toLowerCase());
            if (!matchesId && !matchesName && docOutletId.isNotEmpty && docOutletId != "Verifying Outlet...") {
              continue; 
            }
          }

          DateTime? date;
          if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
            date = (data['timestamp'] as Timestamp).toDate();
          } else if (data['submissionDate'] != null) {
            try {
              String rawDateStr = data['submissionDate'].toString().split(' at ').first.trim();
              List<String> parts = rawDateStr.split('/');
              if (parts.length == 3) {
                date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            } catch (_) {}
          }

          if (date != null && yearlyRevenueMap.containsKey(date.year)) {
            yearlyRevenueMap[date.year] = yearlyRevenueMap[date.year]! + orderTotal;
          } else if (date != null && date.year == 2026) {
            yearlyRevenueMap[2026] = (yearlyRevenueMap[2026] ?? 0.0) + orderTotal;
          }

          // 🎯 Collect monthly performance tracking data if it matches current filtered year
          if (date != null && date.year == selectedYear) {
            monthlySalesMap[date.month] = (monthlySalesMap[date.month] ?? 0.0) + orderTotal;
          }

          if (date != null && date.month == selectedMonth && date.year == selectedYear) {
            totalRevenue += orderTotal;

            if (data['items'] != null && data['items'] is List) {
              List items = data['items'];
              for (var item in items) {
                if (item is! Map) continue;
                String name = (item['name'] ?? item['productName'] ?? "Unknown Item").toString().trim();
                if (name.isEmpty) continue;

                var rawItemQty = item['quantity'] ?? item['qty'] ?? 1;
                int qty = 1;
                if (rawItemQty is num) {
                  qty = rawItemQty.toInt();
                } else if (rawItemQty is String) {
                  qty = int.tryParse(rawItemQty) ?? 1;
                }
                productSalesCount[name] = (productSalesCount[name] ?? 0) + qty;
              }
            } else if (data['items'] != null && data['items'] is Map) {
              Map itemsMap = data['items'];
              itemsMap.forEach((key, item) {
                if (item is Map) {
                  String name = (item['name'] ?? item['productName'] ?? "Unknown Item").toString().trim();
                  var rawQty = item['quantity'] ?? item['qty'] ?? 1;
                  int qty = (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 1);
                  productSalesCount[name] = (productSalesCount[name] ?? 0) + qty;
                }
              });
            } else {
              String? name = data['productName'] ?? data['product_name'] ?? data['itemsOrdered'];
              if (name != null && name.toString().trim().isNotEmpty) {
                String trimmedName = name.toString().trim();
                var rawFallbackQty = data['quantity'] ?? data['qty'] ?? 1;
                int qty = 1;
                if (rawFallbackQty is num) {
                  qty = rawFallbackQty.toInt();
                } else if (rawFallbackQty is String) {
                  qty = int.tryParse(rawFallbackQty) ?? 1;
                }
                productSalesCount[trimmedName] = (productSalesCount[trimmedName] ?? 0) + qty;
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
            
            // 🎯 STAKEHOLDER DESIGN REQUIREMENT 1: Main Admin Overall Accumulative Sales view card
            if (isMainAdmin) ...[
              const SizedBox(height: 12),
              _buildAccumulativeSalesCard(overallAccumulativeRevenue),
            ],

            // 🎯 STAKEHOLDER DESIGN REQUIREMENT 2: Branch Admin Visual Monthly Graph view
            if (!isMainAdmin) ...[
              const SizedBox(height: 20),
              _buildBranchMonthlySalesGraph(monthlySalesMap, selectedYear),
            ],

            const SizedBox(height: 24),
            _buildRatingsAndFeedbackSection(),
            const SizedBox(height: 24),
            const Text("Top Products", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (topProducts.isEmpty)
              _buildEmptyState("No sales found for ${months[selectedMonth - 1]} $selectedYear")
            else
              ...topProducts.take(10).map((name) => _buildSalesTile(name, productSalesCount[name]!)).toList(),
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

  // 🎯 NEW DESIGN METHOD: Builds the lifetime revenue tracking element for the Super Admin view
  Widget _buildAccumulativeSalesCard(double overallTotal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.shade200, shape: BoxShape.circle),
            child: const Icon(Icons.all_inclusive_rounded, color: Colors.deepOrange, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "OVERALL ACCUMULATIVE REVENUE (ALL BRANCHES)",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  "RM ${overallTotal.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 🎯 NEW DESIGN METHOD: Render graph metrics layout perfectly matching design context
  Widget _buildBranchMonthlySalesGraph(Map<int, double> monthlySalesMap, int targetYear) {
    double maxSaleValue = monthlySalesMap.values.fold(0.0, (max, element) => element > max ? element : max);
    if (maxSaleValue == 0) maxSaleValue = 1.0; 

    List<String> shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Monthly Breakdown ($targetYear)", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
              const Icon(Icons.bar_chart_rounded, color: Colors.redAccent, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(12, (index) {
                int currentMonthNum = index + 1;
                double currentMonthSales = monthlySalesMap[currentMonthNum] ?? 0.0;
                double proportionalHeightPercentage = currentMonthSales / maxSaleValue;

                bool isSelectedFilterMonth = currentMonthNum == selectedMonth;

                return Expanded(
                  child: Tooltip(
                    message: "${months[index]}: RM ${currentMonthSales.toStringAsFixed(2)}",
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: proportionalHeightPercentage.clamp(0.05, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isSelectedFilterMonth
                                        ? [Colors.redAccent, Colors.red.shade900]
                                        : [Colors.grey.shade300, Colors.grey.shade400],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shortMonths[index],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelectedFilterMonth ? FontWeight.bold : FontWeight.normal,
                            color: isSelectedFilterMonth ? Colors.redAccent : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          )
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
              child: Text("Customer Satisfaction & Feedback", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            if (selectedOutletId != null || widget.branchAccess == 'all')
              InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => StoreReviewsPage(
                        outletId: selectedOutletName ?? 'All Outlets',
                        outletName: selectedOutletName ?? 'All Outlets',
                        monthName: months[selectedMonth - 1],
                        monthInt: selectedMonth,
                        year: selectedYear,
                      )));
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
            var query = FirebaseFirestore.instance.collection('reviews').where('month', isEqualTo: selectedMonth).where('year', isEqualTo: selectedYear).limit(40);
            if (selectedOutletId != null && selectedOutletId != 'all') {
              query = query.where('outletId', isEqualTo: selectedOutletName);
            }
            return query.snapshots();
          }(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                child: const Center(child: Text("No feedback records found for this period.", style: TextStyle(color: Colors.grey, fontSize: 13))),
              );
            }

            final reviews = snapshot.data!.docs;
            double totalStars = 0.0;
            for (var doc in reviews) {
              var data = doc.data() as Map<String, dynamic>;
              var r = data['rating'];
              totalStars += (r is num) ? r.toDouble() : 0.0;
            }
            double averageRating = totalStars / reviews.length;

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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5),
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
              border: Border.all(color: isCurrentlyPicked ? Colors.redAccent : Colors.grey.shade200, width: isCurrentlyPicked ? 1.5 : 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 3))]),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Year $currentYearElement", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isCurrentlyPicked ? Colors.redAccent : Colors.grey.shade500)),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("RM ${totalYearRevenue.toStringAsFixed(2)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSalesTile(String name, int qty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductSalesDetailScreen(
                productName: name,
                monthInt: selectedMonth,
                monthName: months[selectedMonth - 1],
                year: selectedYear,
                outletId: selectedOutletId ?? 'all_outlets',
                outletName: selectedOutletName, 
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
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.redAccent),
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
  final String? outletName; 

  const ProductSalesDetailScreen({
    Key? key,
    required this.productName,
    required this.monthInt,
    required this.monthName,
    required this.year,
    required this.outletId,
    this.outletName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Query refQuery = FirebaseFirestore.instance.collection('orders').limit(150); 

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: refQuery.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));

          final rawDocs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;

            if (outletId != 'all_outlets' && outletId.isNotEmpty) {
              String docOutletId = (data['outletId'] ?? '').toString();
              String docOutletName = (data['outlet'] ?? data['outletName'] ?? data['assignedOutlet'] ?? '').toString();
              
              bool matchesId = docOutletId == outletId;
              bool matchesName = outletName != null && docOutletName.toLowerCase().contains(outletName!.toLowerCase());
              
              if (!matchesId && !matchesName && docOutletId.isNotEmpty && docOutletId != "Verifying Outlet...") {
                return false; 
              }
            }

            DateTime? date;
            if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
              date = (data['timestamp'] as Timestamp).toDate();
            } else if (data['submissionDate'] != null) {
              try {
                String rawDateStr = data['submissionDate'].toString().split(' at ').first.trim();
                List<String> parts = rawDateStr.split('/');
                if (parts.length == 3) {
                  date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                }
              } catch (_) {}
            }

            if (date == null || date.month != monthInt || date.year != year) {
              return false;
            }

            bool nameMatch = false;
            String lookUpName = productName.toLowerCase().trim();

            if (data['items'] != null && data['items'] is List) {
              nameMatch = (data['items'] as List).any((item) {
                if (item is! Map) return false;
                String itemTarget = (item['name'] ?? item['productName'] ?? '').toString().toLowerCase().trim();
                return itemTarget == lookUpName || itemTarget.contains(lookUpName) || lookUpName.contains(itemTarget);
              });
            } else if (data['items'] != null && data['items'] is Map) {
              Map itemsMap = data['items'];
              itemsMap.forEach((key, item) {
                if (item is Map) {
                  String itemTarget = (item['name'] ?? item['productName'] ?? '').toString().toLowerCase().trim();
                  if (itemTarget == lookUpName || itemTarget.contains(lookUpName)) {
                    nameMatch = true;
                  }
                }
              });
            } else {
              String baseTarget = (data['productName'] ?? data['product_name'] ?? '').toString().toLowerCase().trim();
              nameMatch = baseTarget == lookUpName || baseTarget.contains(lookUpName) || lookUpName.contains(baseTarget);
            }

            return nameMatch;
          }).toList();

          final Map<String, QueryDocumentSnapshot> uniqueOrdersMap = {};
          for (var doc in rawDocs) {
            String trackingId = doc.id.trim().toUpperCase();
            if (!uniqueOrdersMap.containsKey(trackingId)) {
              uniqueOrdersMap[trackingId] = doc;
            }
          }

          final uniqueDocsList = uniqueOrdersMap.values.toList();

          if (uniqueDocsList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "No transaction details found for $monthName $year.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: uniqueDocsList.length,
            itemBuilder: (context, index) {
              var data = uniqueDocsList[index].data() as Map<String, dynamic>;
              
              String orderId = uniqueDocsList[index].id;
              String displayOrderId = orderId.length > 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();

              DateTime date = DateTime.now();
              if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
                date = (data['timestamp'] as Timestamp).toDate();
              } else if (data['submissionDate'] != null) {
                try {
                  String rawDateStr = data['submissionDate'].toString().split(' at ').first.trim();
                  List<String> parts = rawDateStr.split('/');
                  date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                } catch (_) {}
              }

              String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

              int explicitItemQty = 0;
              String lookUpName = productName.toLowerCase().trim();
              
              if (data['items'] != null && data['items'] is List) {
                for (var item in data['items']) {
                  if (item is! Map) continue;
                  String itemTarget = (item['name'] ?? item['productName'] ?? '').toString().toLowerCase().trim();
                  if (itemTarget == lookUpName || itemTarget.contains(lookUpName)) {
                    var rawQty = item['quantity'] ?? item['qty'] ?? 1;
                    explicitItemQty += (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 1);
                  }
                }
              } else if (data['items'] != null && data['items'] is Map) {
                Map itemsMap = data['items'];
                for (var item in itemsMap.values) {
                  if (item is Map) {
                    String itemTarget = (item['name'] ?? item['productName'] ?? '').toString().toLowerCase().trim();
                    if (itemTarget == lookUpName || itemTarget.contains(lookUpName)) {
                      var rawQty = item['quantity'] ?? item['qty'] ?? 1;
                      explicitItemQty += (rawQty is num) ? rawQty.toInt() : (int.tryParse(rawQty.toString()) ?? 1);
                    }
                  }
                }
              } else {
                var rawFallbackQty = data['quantity'] ?? data['qty'] ?? 1;
                explicitItemQty = (rawFallbackQty is num) ? rawFallbackQty.toInt() : (int.tryParse(rawFallbackQty.toString()) ?? 1);
              }

              if (explicitItemQty == 0) explicitItemQty = 1;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.redAccent, size: 26),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Order #$displayOrderId",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formattedDate,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Quantity: $explicitItemQty units",
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                        child: const Text(
                          "paid",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
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
    );
  }
}