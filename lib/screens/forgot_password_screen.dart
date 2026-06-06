import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this line
import '../widgets/custom_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // 1. Add a controller to grab the email text
  final TextEditingController emailController = TextEditingController();
  bool isLoading = false;

  // 2. The function to actually trigger the Firebase Reset Email
  Future<void> _resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage("Please enter your email address first.");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🎯 This is the magic line that sends the real Google reset link
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      _showMessage("Success! Check your Gmail inbox (and Spam) for the reset link.");
      
      // Go back to login after 2 seconds so they can sign in with the new password
      Future.delayed(Duration(seconds: 2), () {
        Navigator.pop(context);
      });

    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? "An error occurred. Check if the email is correct.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Forgot Password', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Please enter your email address. You will receive a link to create a new password via email.',
              style: TextStyle(fontSize: 16, color: Colors.grey[800]),
            ),
            SizedBox(height: 20),
            
            // 3. Link the controller here
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 20),

            // 4. Update the button to show a loading spinner or the text
            isLoading 
              ? Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : CustomButton(
                  text: 'SEND RESET LINK',
                  onPressed: _resetPassword, // Connect the function here
                ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}