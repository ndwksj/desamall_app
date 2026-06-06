import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  bool _isObscured = true; 
  bool _isLoading = false;

  void _validateAndSubmit() async {
    String newPass = _passController.text.trim();
    String confirmPass = _confirmController.text.trim();

    // 1. Length Check (8-12 characters)
    if (newPass.length < 8 || newPass.length > 12) {
      _showMsg("Password must be between 8 and 12 characters");
      return;
    }

    // 2. Number Check (At least 1 number)
    if (!newPass.contains(RegExp(r'[0-9]'))) {
      _showMsg("Password must contain at least one number");
      return;
    }

    // 3. Special Character Check (At least 1 special character)
    // This looks for characters like ! @ # $ % ^ & * etc.
    if (!newPass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      _showMsg("Password must contain at least one special character");
      return;
    }

    // 4. Match Check
    if (newPass != confirmPass) {
      _showMsg("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(newPass);
      _showMsg("Password updated successfully! ✅", isError: false);
      Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showMsg("Security timeout. Please logout and login again first.");
      } else {
        _showMsg(e.message ?? "An error occurred");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Update Password", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildRequirementItem("8-12 characters total"),
            _buildRequirementItem("At least 1 number"),
            _buildRequirementItem("At least 1 special character (@, #, !, etc.)"),
            const SizedBox(height: 30),
            
            TextField(
              controller: _passController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                labelText: "New Password",
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isObscured = !_isObscured),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _confirmController,
              obscureText: _isObscured,
              decoration: InputDecoration(
                labelText: "Confirm New Password",
                prefixIcon: const Icon(Icons.lock_reset),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _validateAndSubmit,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("UPDATE PASSWORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}