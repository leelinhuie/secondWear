import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled3/authentication/auth_controller.dart';
import 'package:untitled3/authentication/forgot.dart';
import 'package:untitled3/authentication/signup.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();
  final AuthController authController = Get.put(AuthController());

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    await authController.signIn(
      email: email.text,
      password: password.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildLoginForm(),
                const SizedBox(height: 20),
                _buildCreateAccountButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'SUSTAINABLE CLOTHING EXCHANGE',
      style: TextStyle(
        fontSize: 26,
        color: Colors.green[800],
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green, width: 2),
      ),
      child: Column(
        children: [
          _buildTextField(
            controller: email,
            label: 'Email',
            hint: 'Email Address',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: password,
            label: 'Password',
            hint: 'Password',
            isPassword: true,
          ),
          const SizedBox(height: 20),
          _buildLoginButton(),
          _buildForgotPasswordButton(),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
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
    );
  }

  Widget _buildLoginButton() {
    return Obx(() => ElevatedButton(
          onPressed: authController.isLoading.value ? null : signIn,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(vertical: 15),
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: authController.isLoading.value
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  'Log In',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
        ));
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () => Get.to(() => const Forgot()),
        child: const Text(
          'Forgot password?',
          style: TextStyle(color: Colors.green),
        ),
      ),
    );
  }

  Widget _buildCreateAccountButton() {
    return OutlinedButton(
      onPressed: () => Get.to(() => const Signup()),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: Colors.green),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: const Text(
        'Create a new account',
        style: TextStyle(color: Colors.green, fontSize: 16),
      ),
    );
  }
}
