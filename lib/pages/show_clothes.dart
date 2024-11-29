import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/search_service.dart';
import '../services/save_clothes_service.dart';
import '../widgets/drawer.dart';
import '../widgets/filter.dart';

class DisplayClothesPage extends StatefulWidget {
  @override
  _DisplayClothesPageState createState() => _DisplayClothesPageState();
}

class _DisplayClothesPageState extends State<DisplayClothesPage> {
  final SearchService searchService = SearchService();
  final SaveClothesService _saveClothesService = SaveClothesService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _searchQuery = '';
  String? _selectedCategory;

  // Add this method to filter results locally
  List<DocumentSnapshot> _filterResults(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty && _selectedCategory == null) return docs;

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final title = data['title'].toString().toLowerCase();
      final description = (data['description'] ?? '').toString().toLowerCase();
      final category = (data['category'] ?? '').toString().toLowerCase();

      final matchesSearch = title.contains(_searchQuery.toLowerCase()) ||
          description.contains(_searchQuery.toLowerCase());

      final matchesCategory = _selectedCategory == null || _selectedCategory == 'All' || category == _selectedCategory!.toLowerCase();

      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(160),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: Colors.green.shade700,
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  "SecondWear",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Sustainable Clothing Exchange Platform and Donation System",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search Clothes',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.filter_list, color: Colors.green.shade700),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) {
                              return FilterWidget(
                                selectedCategory: _selectedCategory,
                                onCategoryChanged: (category) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
      drawer: DrawerMenu(),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clothes')
              .where('isApproved', isEqualTo: true)
              .orderBy('uploadedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No clothes available'));
            }

            // Filter the results
            final filteredDocs = _filterResults(snapshot.data!.docs);

            if (filteredDocs.isEmpty) {
              return const Center(child: Text('No matching clothes found'));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.7,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final doc = filteredDocs[index];
                final data = doc.data() as Map<String, dynamic>;

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                              ),
                              child: Image.network(
                                data['imageUrl'],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.green.shade700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    data['donorId'] == _auth.currentUser?.uid 
                                        ? Icons.person_outline  // Show different icon for own items
                                        : Icons.add,
                                    color: data['donorId'] == _auth.currentUser?.uid 
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade700,
                                  ),
                                  onPressed: data['donorId'] == _auth.currentUser?.uid
                                      ? () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'This is your own donation (Donor: ${data['donorEmail'] ?? 'Unknown'})',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                              backgroundColor: Colors.orange,
                                            ),
                                          );
                                        }
                                      : () async {
                                          try {
                                            String clothesId = doc.id;
                                            await _saveClothesService.saveClothes(
                                              clothesId,
                                              data,
                                            );

                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Item saved successfully!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } catch (e) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(e.toString()),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'],
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
                              data['description'] ?? 'Description',
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}