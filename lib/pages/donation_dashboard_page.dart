import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/drawer.dart';

class DonationDashboardPage extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DonationDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        title: const Text('Donation Dashboard'),
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontFamily: 'Cardo',
        ),
        backgroundColor: Color.fromARGB(255, 144, 189, 134),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('clothes')
            .where('donorId', isEqualTo: _auth.currentUser?.uid)
            .where('orderStatus', whereIn: ['approved', 'completed'])
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No donation data available',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Filter out donations with null completedAt
          final validDonations = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['completedAt'] != null;
          }).toList();

          // Process the data for charts
          final weeklyData = _processWeeklyData(validDonations);
          final monthlyPercentage = _calculateMonthlyPercentage(validDonations);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCard(
                  'Total Donations',
                  validDonations.length.toString(),
                  Icons.volunteer_activism,
                  Colors.red,
                ),
                const SizedBox(height: 20),
                _buildMonthlyStats(monthlyPercentage),
                const SizedBox(height: 20),
                if (weeklyData.isNotEmpty) // Only show chart if there's data
                  _buildWeeklyChart(weeklyData)
                else
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No weekly data available',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyStats(double percentage) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Growth',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  percentage >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: percentage >= 0 ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '${percentage.abs().toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: percentage >= 0 ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyChart(List<FlSpot> data) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Donations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('W${value.toInt() + 1}');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _processWeeklyData(List<QueryDocumentSnapshot> donations) {
    Map<int, int> weeklyCount = {};
    final now = DateTime.now();

    for (var donation in donations) {
      try {
        final data = donation.data() as Map<String, dynamic>;
        final completedAt = data['completedAt'];
        
        // Skip if completedAt is null
        if (completedAt == null) continue;
        
        final timestamp = (completedAt as Timestamp).toDate();
        
        if (now.difference(timestamp).inDays <= 28) {
          final weekNumber = (now.difference(timestamp).inDays / 7).floor();
          weeklyCount[weekNumber] = (weeklyCount[weekNumber] ?? 0) + 1;
        }
      } catch (e) {
        print('Error processing donation data: $e');
        continue; // Skip this donation if there's an error
      }
    }

    // Ensure we have data for all weeks
    return List.generate(4, (index) {
      return FlSpot(index.toDouble(), (weeklyCount[index] ?? 0).toDouble());
    }).reversed.toList(); // Show oldest to newest
  }

  double _calculateMonthlyPercentage(List<QueryDocumentSnapshot> donations) {
    int currentMonth = 0;
    int previousMonth = 0;
    final now = DateTime.now();

    for (var donation in donations) {
      try {
        final data = donation.data() as Map<String, dynamic>;
        final completedAt = data['completedAt'];
        
        // Skip if completedAt is null
        if (completedAt == null) continue;
        
        final timestamp = (completedAt as Timestamp).toDate();
        
        if (now.difference(timestamp).inDays <= 30) {
          currentMonth++;
        } else if (now.difference(timestamp).inDays <= 60) {
          previousMonth++;
        }
      } catch (e) {
        print('Error calculating monthly percentage: $e');
        continue; // Skip this donation if there's an error
      }
    }

    // Handle edge cases
    if (previousMonth == 0) {
      if (currentMonth == 0) return 0; // No donations in either month
      return 100; // Only donations in current month
    }
    
    return ((currentMonth - previousMonth) / previousMonth) * 100;
  }
} 