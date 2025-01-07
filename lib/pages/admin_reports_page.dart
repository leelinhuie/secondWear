import 'package:flutter/material.dart';
import 'package:untitled3/services/firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/drawer.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final firestoreServices = FirestoreServices();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        title: const Text('Manage Reports'),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontFamily: 'Cardo',
        ),
        backgroundColor: const Color.fromARGB(255, 144, 189, 134),
        iconTheme: const IconThemeData(color: Colors.black),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Resolved'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingReports(),
          _buildResolvedReports(),
        ],
      ),
    );
  }

  Widget _buildPendingReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('action', isNull: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        return _buildReportsList(snapshot, isPending: true);
      },
    );
  }

  Widget _buildResolvedReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reports')
          .where('action', isEqualTo: 'deleted')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        return _buildReportsList(snapshot, isPending: false);
      },
    );
  }

  Widget _buildReportsList(AsyncSnapshot<QuerySnapshot> snapshot, {required bool isPending}) {
    if (snapshot.hasError) {
      return Center(child: Text('Error: ${snapshot.error}'));
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.fromARGB(255, 144, 189, 134),
          ),
        ),
      );
    }

    final reports = snapshot.data?.docs ?? [];

    if (reports.isEmpty) {
      return Center(
        child: Text(
          isPending ? 'No pending reports' : 'No resolved reports',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index].data() as Map<String, dynamic>;
        final reportId = reports[index].id;

        return FutureBuilder<Map<String, dynamic>>(
          future: firestoreServices.getContent(
            report['contentId'],
            report['contentType'],
          ),
          builder: (context, contentSnapshot) {
            final contentData = contentSnapshot.data ?? {};
            final contentMessage = report['contentType'] == 'post'
                ? contentData['message']
                : contentData['comment'];

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${report['reportType']} Report',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (report['severity'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: report['severity'] == 'high'
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Severity: ${report['severity']}',
                              style: TextStyle(
                                color: report['severity'] == 'high'
                                    ? Colors.red
                                    : Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Reported by', report['reportedBy']),
                    _buildInfoRow('Reported user', report['reportedUser']),
                    _buildInfoRow('Content type', report['contentType']),
                    if (report['action'] != null)
                      _buildInfoRow('Action taken', report['action']),

                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey[300]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reported Content:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (contentSnapshot.connectionState == ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator())
                          else if (contentSnapshot.hasError)
                            Text('Error loading content: ${contentSnapshot.error}')
                          else if (contentMessage == null)
                            Text('Content not found (may have been deleted)')
                          else
                            Text(contentMessage),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    if (isPending)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => _handleDeleteContent(
                              context,
                              report,
                              reportId,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete Content'),
                          ),
                        ],
                      ),
                    if (!isPending)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Resolved',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteContent(
    BuildContext context,
    Map<String, dynamic> report,
    String reportId,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        if (report['contentType'] == 'post') {
          await firestoreServices.deletePost(
            report['contentId'],
            report['reportedUser'],
          );
        } else {
          await firestoreServices.deleteComment(
            report['contentId'],
          );
        }

        await FirebaseFirestore.instance
            .collection('reports')
            .doc(reportId)
            .update({
          'action': 'deleted',
          'actionTimestamp': FieldValue.serverTimestamp(),
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error deleting content'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
