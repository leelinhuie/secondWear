import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:untitled3/services/firestore.dart';
import 'package:untitled3/services/llma_api.dart';

class ReportButton extends StatelessWidget {
  final String contentId;
  final String contentType; // 'post' or 'comment'
  final String reportedUserEmail;

  const ReportButton({
    super.key,
    required this.contentId,
    required this.contentType,
    required this.reportedUserEmail,
  });

  Future<void> _handleInappropriateContent({
    required BuildContext context,
    required FirestoreServices firestoreServices,
    required String? currentUserEmail,
  }) async {
    final aiService = AIService();
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );

    try {
      // Get the reported content from Firestore
      final contentDoc = await firestoreServices.getContent(contentId, contentType);
      if (contentDoc.isEmpty) {
        print('DEBUG: Content document is empty');
        throw 'Content not found';
      }

      final contentText = contentType == 'post' 
          ? contentDoc['message'] ?? '' 
          : contentDoc['comment'] ?? '';
      
      print('DEBUG: Content to check: "$contentText"');

      // Check content with AI
      final isInappropriate = await aiService.checkInappropriateContent(contentText);
      print('DEBUG: AI check result: $isInappropriate');

      // Remove loading indicator
      if (context.mounted) Navigator.pop(context);

      if (isInappropriate) {
        print('DEBUG: Content flagged as inappropriate');
        try {
          // Immediately delete the content if it violates policy
          if (contentType == 'post') {
            print('DEBUG: Attempting to delete post: $contentId');
            await firestoreServices.deletePost(contentId, reportedUserEmail);
            print('DEBUG: Post deleted successfully');
          } else {
            print('DEBUG: Attempting to delete comment: $contentId');
            await firestoreServices.deleteComment(contentId);
            print('DEBUG: Comment deleted successfully');
          }

          // Add to reports collection for tracking
          print('DEBUG: Adding report with high severity');
          await firestoreServices.addReport(
            contentId: contentId,
            contentType: contentType,
            reportType: 'inappropriate',
            reportedBy: currentUserEmail ?? 'Anonymous',
            reportedUser: reportedUserEmail,
            aiVerified: true,
            severity: 'high',
            action: 'deleted',
          );
          print('DEBUG: Report added successfully');

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content has been removed for violating community guidelines'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error processing report'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print('DEBUG: Content deemed appropriate by AI');
        // Simply show thank you message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for reporting'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      Navigator.pop(context); // Close report dialog
    } catch (e) {
      Navigator.pop(context); // Remove loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error processing report'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showReportDialog(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final firestoreServices = FirestoreServices();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Content'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Why are you reporting this content?'),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Inappropriate Content'),
                onTap: () => _handleInappropriateContent(
                  context: context,
                  firestoreServices: firestoreServices,
                  currentUserEmail: currentUser?.email,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.warning),
                title: const Text('Spam'),
                onTap: () async {
                  await firestoreServices.addReport(
                    contentId: contentId,
                    contentType: contentType,
                    reportType: 'spam',
                    reportedBy: currentUser?.email ?? 'Anonymous',
                    reportedUser: reportedUserEmail,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dangerous),
                title: const Text('Harassment'),
                onTap: () async {
                  await firestoreServices.addReport(
                    contentId: contentId,
                    contentType: contentType,
                    reportType: 'harassment',
                    reportedBy: currentUser?.email ?? 'Anonymous',
                    reportedUser: reportedUserEmail,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade700,
              ),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.report_problem_outlined, color: Colors.green.shade700),
      onPressed: () => _showReportDialog(context),
    );
  }
}