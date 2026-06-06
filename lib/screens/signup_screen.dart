import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desamall_app/screens/admin/home_admin.dart'; // Make sure this path matches your project structure
import 'verify_email_screen.dart'; 

class SignupScreen extends StatefulWidget {
  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Password validation logic
  bool _isPasswordValid(String password) {
    if (password.length < 8 || password.length > 12) return false;
    bool hasNumber = password.contains(RegExp(r'[0-9]'));
    bool hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasNumber && hasSpecial;
  }

  void _handleSignup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill in all fields");
      return;
    }

    // 🔑 Email Structure Format Validation (Regex)
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showError("Please enter a valid email format (e.g., name@gmail.com)");
      return;
    }

    // 🔑 Strict Domain Name Typo Checks
    final lowerEmail = email.toLowerCase();
    if (lowerEmail.contains('@gamil.') || lowerEmail.contains('@gmal.')) {
      _showError("Invalid email domain! Did you mean @gmail.com?");
      return;
    }
    if (lowerEmail.contains('@yaho.') || lowerEmail.contains('@ymil.')) {
      _showError("Invalid email domain! Did you mean @yahoo.com?");
      return;
    }
    if (lowerEmail.contains('@hotmal.')) {
      _showError("Invalid email domain! Did you mean @hotmail.com?");
      return;
    }

    if (!_isPasswordValid(password)) {
      _showError("Password must be 8-12 characters with a number & symbol");
      return;
    }

    if (password != confirmPassword) {
      _showError("Passwords do not match!");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = userCredential.user!.uid;
      bool isAdmin = email.toLowerCase().contains("admin") || email.toLowerCase().endsWith("@desamall.com");

      // 2. Only trigger Verification Email if user is NOT an admin
      if (!isAdmin) {
        await userCredential.user?.sendEmailVerification();
      }

      // 3. Save data to Firestore (keeping branch configurations flexible)
      if (isAdmin) {
        // Checking if it's one of your pre-made accounts to retain specific branch pointers
        String branchAccessValue = 'all';
        String roleValue = 'admin';

        if (email.toLowerCase().contains("kepalabatas")) {
          branchAccessValue = 'kepala_batas';
          roleValue = 'branch_admin';
        } else if (email.toLowerCase().contains("lipis")) {
          branchAccessValue = 'lipis';
          roleValue = 'branch_admin';
        } else if (email.toLowerCase().contains("ipoh")) {
          branchAccessValue = 'ipoh';
          roleValue = 'branch_admin';
        }

        await FirebaseFirestore.instance.collection('admins').doc(uid).set({
          'uid': uid, 
          'name': name, 
          'email': email, 
          'role': roleValue,
          'branchAccess': branchAccessValue,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid, 'name': name, 'email': email, 'role': 'customer',
          'points_earned': 0.0, 'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // 4. Redirect based on Admin status
      if (mounted) {
        if (isAdmin) {
          // Admins go directly to Dashboard, skipping verify screen entirely
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => HomeAdmin())
          );
        } else {
          // Regular customers go to Verification Screen
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => const VerifyEmailScreen())
          );
        }
      }

    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? "Signup failed");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 220,
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
                  children: const [
                    SizedBox(height: 40),
                    Icon(Icons.person_add_outlined, size: 60, color: Colors.white),
                    SizedBox(height: 10),
                    Text("Create Account", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInputField(nameController, "Full Name", Icons.person_outline),
                  const SizedBox(height: 15),
                  _buildInputField(emailController, "Email Address", Icons.email_outlined, type: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildInputField(passwordController, "Password", Icons.lock_outline, isPassword: true, isVisible: _isPasswordVisible, onToggle: () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
                  const SizedBox(height: 15),
                  _buildInputField(confirmPasswordController, "Re-confirm Password", Icons.lock_reset_outlined, isPassword: true, isVisible: _isConfirmPasswordVisible, onToggle: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible)),
                  
                  // Requirement box
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.redAccent.withOpacity(0.1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Password Requirements:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        const SizedBox(height: 8),
                        _buildRequirement("• 8 to 12 characters"),
                        _buildRequirement("• At least one number (0-9)"),
                        _buildRequirement("• One special character (@, #, etc.)"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Signup Button
                  Container(
                    height: 60,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _handleSignup,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF1744), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                      child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIGN UP", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    ),
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?", style: TextStyle(color: Colors.grey.shade600)),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Login", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Input Field Helper
  Widget _buildInputField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool isVisible = false, VoidCallback? onToggle, TextInputType type = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? !isVisible : false,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.redAccent),
          suffixIcon: isPassword ? IconButton(icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey), onPressed: onToggle) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [const Icon(Icons.check_circle_outline, size: 12, color: Colors.redAccent), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 11, color: Colors.black54))]),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}