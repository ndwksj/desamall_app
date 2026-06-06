import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desamall_app/screens/admin/home_admin.dart'; // Ensure this matches your directory path

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool _isPasswordVisible = false;

  void _handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.orange),
      );
      return;
    }

    // 🔑 Email Structure Format Validation (Regex)
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email format (e.g., name@gmail.com)"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    // 🔑 Strict Domain Name Typo Checks
    final lowerEmail = email.toLowerCase();
    if (lowerEmail.contains('@gamil.') || lowerEmail.contains('@gmal.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email! Did you mean @gmail.com?"), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (lowerEmail.contains('@yaho.') || lowerEmail.contains('@ymil.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email! Did you mean @yahoo.com?"), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (lowerEmail.contains('@hotmal.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email domain! Did you mean @hotmail.com?"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        String uid = user.uid;

        print("DEBUG: Active User UID logging in is: >>> $uid <<<");

        // 1. 'admins' collection 
        DocumentSnapshot adminDoc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
        if (adminDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Welcome back, Admin!")));
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomeAdmin()),
            );
          }
          return;
        }

        // 2. 'users' collection (Regular Customers)
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login Successful!")));
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User profile not found in database."), backgroundColor: Colors.orange));
          }
          await FirebaseAuth.instance.signOut();
        }
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage = "An error occurred. Please try again.";
      if (e.code == 'user-not-found') errorMessage = "No account found with this email.";
      else if (e.code == 'wrong-password') errorMessage = "Incorrect password.";
      else if (e.code == 'invalid-email') errorMessage = "The email address is not valid.";

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 300,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(80)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.white),
                    const SizedBox(height: 10),
                    const Text("desamall", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3, shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)])),
                    const Text("Premium Quality Local Goods", style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
              child: Column(
                children: [
                  _buildInputField(controller: emailController, label: "Email Address", icon: Icons.alternate_email, type: TextInputType.emailAddress),
                  const SizedBox(height: 20),
                  _buildInputField(controller: passwordController, label: "Password", icon: Icons.lock_outline_rounded, isPassword: true),
                  Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pushNamed(context, '/forgot'), child: const Text("Forgot Password?", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1744), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("LOG IN", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("New to desamall?", style: TextStyle(color: Colors.grey.shade600)),
                      TextButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: const Text("Create Account", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false, TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !_isPasswordVisible : false,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.redAccent),
          suffixIcon: isPassword ? IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}