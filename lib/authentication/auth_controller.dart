import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class AuthController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RxBool isLoading = false.obs;
  final RxBool isAdmin = false.obs;

  // Admin credentials
  static const String adminEmail = "admin@secondwear.com";
  static const String adminPassword = "admin123";

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      isLoading.value = true;
      
      // Check for admin login
      if (email == adminEmail && password == adminPassword) {
        isAdmin.value = true;
        // Create or sign in admin account if it doesn't exist
        try {
          await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } catch (e) {
          // If admin account doesn't exist, create it
          await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        return;
      }

      // Regular user login
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      isAdmin.value = false;
    } catch (e) {
      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await _auth.signOut();
      isAdmin.value = false;
      // The Wrapper will handle navigation automatically
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      rethrow; // Rethrow to handle in the drawer
    } finally {
      isLoading.value = false;
    }
  }
} 