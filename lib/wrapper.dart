import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:untitled3/authentication/auth_controller.dart';
import 'package:untitled3/authentication/login.dart';
import 'package:untitled3/pages/admin_panel.dart';
import 'package:untitled3/pages/post.dart';

class Wrapper extends StatelessWidget {
  Wrapper({super.key});

  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If user is logged in
        if (snapshot.hasData) {
          // Check if the logged-in user is admin
          if (snapshot.data?.email == AuthController.adminEmail) {
            return const AdminPanel();
          }
          // Regular user
          return const Post();
        }
        // If user is not logged in
        return const Login();
      },
    );
  }
}
