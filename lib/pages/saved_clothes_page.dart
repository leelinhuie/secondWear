import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart'; // Import Lottie
import '../widgets/drawer.dart';
import 'checkout_page.dart';
import '../services/save_clothes_service.dart';

class SavedClothesPage extends StatefulWidget {
  const SavedClothesPage({Key? key}) : super(key: key);

  @override
  _SavedClothesPageState createState() => _SavedClothesPageState();
}

class _SavedClothesPageState extends State<SavedClothesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SaveClothesService _saveClothesService = SaveClothesService();
  final List<String> _selectedClothesIds = [];

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Saved Clothes'),
        ),
        body: const Center(
          child: Text('Please sign in to view your saved clothes.'),
        ),
      );
    }

    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        title: const Text('Saved Clothes'),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontFamily: 'Cardo',
        ),
        backgroundColor: const Color(0xFFC8DFC3),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('saved_clothes')
                  .where('userId', isEqualTo: currentUser.uid)
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Lottie.asset(
                      'lib/assets/loading.json',
                      width: 200,
                      height: 200,
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No saved clothes found'));
                }

                final savedDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: 80,
                  ),
                  itemCount: savedDocs.length,
                  itemBuilder: (context, index) {
                    final doc = savedDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final itemData = data['itemData'] as Map<String, dynamic>? ?? {};
                    final clothesId = data['clothesId'] as String? ?? '';
                    final isSelected = _selectedClothesIds.contains(clothesId);

                    String displayImage = '';
                    if (itemData['imageUrls'] is List) {
                      final urls = itemData['imageUrls'] as List<dynamic>;
                      if (urls.isNotEmpty) displayImage = urls.first.toString();
                    }

                    if (displayImage.isEmpty && itemData.containsKey('imageUrl')) {
                      displayImage = itemData['imageUrl']?.toString() ?? '';
                    }

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (displayImage.isNotEmpty)
                                Image.network(
                                  displayImage,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 200,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          const Color(0xFFC8DFC3),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: double.infinity,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemData['title']?.toString() ?? 'Untitled',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      itemData['description']?.toString() ?? 'No description',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedClothesIds.remove(clothesId);
                                  } else {
                                    _selectedClothesIds.add(clothesId);
                                  }
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected ? Colors.green.shade700 : Colors.white,
                                  border: Border.all(
                                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isSelected
                                    ? const Center(
                                        child: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            if (_selectedClothesIds.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: ElevatedButton(
                  onPressed: _navigateToCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDC29A),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        'Checkout (${_selectedClothesIds.length} items)',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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

  void _navigateToCheckout() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPage(
            selectedClothesIds: List.from(_selectedClothesIds),
          ),
        ),
      );

      if (result == true) {
        await _saveClothesService.removeMultipleSavedClothes(_selectedClothesIds);
        setState(() {
          _selectedClothesIds.clear();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Items have been checked out and removed from saved items'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
