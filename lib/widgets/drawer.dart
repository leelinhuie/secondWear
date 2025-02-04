import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled3/pages/upload_clothes.dart';
import 'package:untitled3/pages/show_clothes.dart';
import 'package:untitled3/services/firestore.dart';
import 'package:untitled3/pages/post.dart';
import 'package:untitled3/pages/saved_clothes_page.dart';
import 'package:untitled3/pages/admin_panel.dart';
import 'package:get/get.dart';
import 'package:untitled3/authentication/auth_controller.dart';
import 'package:untitled3/wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled3/pages/manage_donations_page.dart';
import 'package:untitled3/pages/my_orders_page.dart';
import 'package:untitled3/pages/donation_qr_codes_page.dart';
import 'package:untitled3/pages/edit_profile_page.dart';
import 'package:untitled3/pages/donation_dashboard_page.dart';
import '../services/reward_points_service.dart';
import 'package:untitled3/pages/admin_reports_page.dart';

class RewardPointsHistoryDialog extends StatelessWidget {
  final RewardPointsService _rewardPointsService = RewardPointsService();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reward Points History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: 16),
            Flexible(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _rewardPointsService.getRewardPointsHistory(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final history = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return ListTile(
                        title: Text('${item['points']} points'),
                        subtitle: Text(item['reason'] ?? 'Unknown reason'),
                        trailing: Text(
                          item['timestamp']?.toDate()?.toString() ?? 'No date',
                          style: TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawerMenu extends StatelessWidget {
  DrawerMenu({super.key});

  final FirestoreServices firestoreServices = FirestoreServices();
  final AuthController authController = Get.find<AuthController>();
  final RewardPointsService _rewardPointsService = RewardPointsService();
  static const String adminEmail = "admin@secondwear.com";

  Future<void> signOut() async {
    try {
      await authController.signOut();
      Get.offAll(() => Wrapper());
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isAdmin = currentUser?.email == adminEmail;

    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 144, 189, 134),
              ),
              child: Center(
                child: const Text(
                  'Menu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cardo',
                  ),
                ),
              ),
            ),

            // User Profile Section (visible to all)
            if (currentUser != null)
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .get(),
                builder: (context, snapshot) {
                  final userData =
                      snapshot.data?.data() as Map<String, dynamic>?;
                  final name = userData?['name'] ?? 'User Profile';
                  final email = currentUser.email ?? '';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => EditProfilePage()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Show only Admin Panel for admin
            if (isAdmin)
              _buildDrawerItem(
                icon: Icons.admin_panel_settings,
                title: 'Admin Panel',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPanel()),
                  );
                },
              ),
              if (isAdmin)
              _buildDrawerItem(
                icon: Icons.admin_panel_settings,
                title: 'Manage Reports',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminReportsPage()),
                  );
                },
              ),

            // Show other menu items only for non-admin users
            if (!isAdmin) ...[
              _buildDrawerItem(
                icon: Icons.grid_view,
                title: 'Available Clothes',
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => DisplayClothesPage()),
                ),
              ),
              _buildDrawerItem(
                icon: Icons.upload,
                title: 'Donate Clothes',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => UploadClothesPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.save_rounded,
                title: 'Saved Clothes',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SavedClothesPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.volunteer_activism,
                title: 'Manage Donations',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ManageDonationsPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.qr_code,
                title: 'Donation QR Codes',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DonationQRCodesPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.shopping_bag,
                title: 'My Orders',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => MyOrdersPage()),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.dashboard,
                title: 'Donation Dashboard',
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => DonationDashboardPage()),
                  );
                },
              ),
              _buildDrawerItem(
              icon: Icons.people,
              title: 'Community',
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Post()),
                );
              },
            ),
            ],


            // Reward Points and Logout (visible to all)
            const Divider(thickness: 1),
           
            if (!isAdmin)
            StreamBuilder<int>(
              stream: _rewardPointsService.getUserPoints(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildDrawerItem(
                    icon: Icons.stars,
                    title: 'Reward Points: ${snapshot.data}',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => RewardPointsHistoryDialog(),
                      );
                    },
                    color: Colors.amber,
                  );
                }
                return const SizedBox();
              },
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: signOut,
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.black),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.grey[800],
          fontSize: 15,
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
    );
  }
}
