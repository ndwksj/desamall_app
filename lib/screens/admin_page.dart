import 'package:flutter/material.dart';
import 'admin/products_admin.dart';
import 'admin/receipts_admin.dart';
import 'admin/users_admin.dart';
import 'admin/profile_admin.dart';
import 'admin/home_admin.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;

  final List<Widget> _sections = [
    HomeAdmin(),
    ProductsAdmin(),
    ReceiptsAdmin(),
    UsersAdmin(),
    ProfileAdmin(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        backgroundColor: Colors.redAccent,
        centerTitle: true,
      ),
      body: _sections[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.redAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Manage Product"),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: "Uploaded Receipt"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Manage Users"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
