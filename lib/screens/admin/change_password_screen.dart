import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  bool _isObscuredNew = true; 
  bool _isObscuredConfirm = true; 
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
        backgroundColor: isError ? const Color(0xFFD32F2F) : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Premium off-white e-commerce background
      body: Column(
        children: [
          // 🌟 Professional Custom Gradient Header (Matches Workspace/Receipt style)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEF5350), Color(0xFFC62828)], 
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 25),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: 40.0), // Perfect center alignment balance
                    child: Text(
                      "CHANGE PASSWORD",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        letterSpacing: 0.8
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Input Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create New Password", 
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Ensure your workspace account remains highly secure.", 
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])
                  ),
                  const SizedBox(height: 18),
                  
                  // 🌟 Modern visual indicators for security standards
                  _buildRequirementSection(),
                  const SizedBox(height: 25),
                  
                  // 🌟 New Password Field
                  _buildInputField(
                    controller: _passController,
                    label: "New Password",
                    hint: "Enter your complex password",
                    prefixIcon: Icons.lock_outline_rounded,
                    isObscured: _isObscuredNew,
                    onToggleVisibility: () => setState(() => _isObscuredNew = !_isObscuredNew),
                  ),
                  const SizedBox(height: 20),
                  
                  // 🌟 Confirm Password Field
                  _buildInputField(
                    controller: _confirmController,
                    label: "Confirm New Password",
                    hint: "Re-enter your password",
                    prefixIcon: Icons.lock_reset_rounded,
                    isObscured: _isObscuredConfirm,
                    onToggleVisibility: () => setState(() => _isObscuredConfirm = !_isObscuredConfirm),
                  ),
                  const SizedBox(height: 35),
                  
                  // 🌟 Premium CTA Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF5350),
                        elevation: 2,
                        shadowColor: const Color(0xFFEF5350).withOpacity(0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isLoading ? null : _validateAndSubmit,
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text(
                            "UPDATE PASSWORD", 
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 Helper for generating premium, minimalist text input layouts
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isObscured,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              prefixIcon: Icon(prefixIcon, color: const Color(0xFFEF5350), size: 22),
              suffixIcon: IconButton(
                icon: Icon(isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey[400], size: 20),
                onPressed: onToggleVisibility,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🌟 Modern horizontal chips system for password requirement details
  Widget _buildRequirementSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: const Color(0xFFC62828).withOpacity(0.8)),
              const SizedBox(width: 6),
              const Text(
                "Security Rules:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC62828)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildRequirementChip("8-12 Characters"),
              _buildRequirementChip("1+ Numbers"),
              _buildRequirementChip("1+ Special Symbols"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 12, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}