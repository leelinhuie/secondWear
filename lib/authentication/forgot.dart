import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart'; // Import GetX for navigation
import 'signup.dart'; // Import your sign-up page

class Forgot extends StatefulWidget {
  const Forgot({super.key});

  @override
  State<Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<Forgot> {
  final TextEditingController email = TextEditingController();
  bool isLoading = false;

  // Debounce function to wait for user input to complete before calling Firebase
  void _debounce(Function func, {Duration duration = const Duration(seconds: 1)}) {
    Future.delayed(duration, () => func());
  }

  Future<void> reset() async {
    setState(() {
      isLoading = true; // Show loading indicator
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.text);
      Get.snackbar('Success', 'Reset link sent to your email', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Failed to send reset link', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() {
        isLoading = false; // Hide loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[100], // Light green background color
      appBar: AppBar(
        backgroundColor: Colors.lightGreen[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.green, // Green lock icon
              ),
              const SizedBox(height: 40),
              Text(
                "FORGOT PASSWORD",
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.green[800], // Darker green text
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: email,
                  onChanged: (text) => _debounce(() {}), // Call debounce for optimization
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Enter Email',
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.green, width: 2),
                    ),
                    labelStyle: TextStyle(color: Colors.green[700]),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator(color: Colors.green) // Show loader when processing
                  : ElevatedButton(
                onPressed: reset, // Call optimized reset function
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Green button color
                  padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Send Link",
                  style: TextStyle(
                    color: Colors.white, // White text
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              // "Not a member? Sign up" link
              TextButton(
                onPressed: () {
                  Get.to(Signup()); // Navigate to sign-up page
                },
                child: const Text(
                  'Not a member? Sign up',
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
