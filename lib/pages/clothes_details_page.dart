import 'package:flutter/material.dart';
import '../services/save_clothes_service.dart';
import 'package:carousel_slider/carousel_slider.dart';

class ClothesDetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String currentUserId;
  final SaveClothesService _saveClothesService = SaveClothesService();

 ClothesDetailsPage({
    Key? key,
    required this.data,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOwnDonation = data['donorId'] == currentUserId;
    int _current = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data['title'] ?? 'Clothes Details',
          style: const TextStyle(color: Colors.black, fontFamily: 'Cardo'), // Title in white
        ),
        backgroundColor:Color.fromARGB(255, 144, 189, 134),
        iconTheme: const IconThemeData(color: Colors.black), // Back arrow in white
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Carousel Section
              if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty)
                Column(
                  children: [
                    CarouselSlider.builder(
                      options: CarouselOptions(
                        height: 300,
                        enlargeCenterPage: true,
                        enableInfiniteScroll: false,
                        autoPlay: true,
                        autoPlayInterval: Duration(seconds: 3),
                        viewportFraction: 0.9,
                        aspectRatio: 16/9,
                        onPageChanged: (index, reason) {
                          _current = index;
                        },
                      ),
                      itemCount: (data['imageUrls'] as List<dynamic>).length,
                      itemBuilder: (BuildContext context, int index, int realIndex) {
                        final imageUrl = data['imageUrls'][index];
                        return Stack(
                          children: [
                            Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 300,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[200],
                                height: 300,
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 80, color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: (data['imageUrls'] as List<dynamic>).map((url) {
                        int index = (data['imageUrls'] as List<dynamic>).indexOf(url);
                        return Container(
                          width: 8.0,
                          height: 8.0,
                          margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _current == index
                                ? Color.fromRGBO(0, 0, 0, 0.9)
                                : Color.fromRGBO(0, 0, 0, 0.4),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              // Details Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      data['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Description
                    Text(
                      data['description'] ?? 'No description provided.',
                      style: const TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Poppin'),
                    ),
                    const SizedBox(height: 16),
                    // Donor Information
                    Row(
                      children: [
                        const Icon(Icons.person_outline, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Donor: ${data['donorEmail'] ?? 'Unknown'}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Category Information
                    Row(
                      children: [
                        const Icon(Icons.category_outlined, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Category: ${data['category'] ?? 'Not specified'}',
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Add to Save Button Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ElevatedButton(
                  onPressed: isOwnDonation
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'You cannot save your own donation (Donor: ${data['donorEmail'] ?? 'Unknown'})',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      : () async {
                          try {
                            String clothesId = data['id'];
                            await _saveClothesService.saveClothes(
                              clothesId,
                              data,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Item saved successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOwnDonation ? Colors.grey :  Color.fromARGB(255, 144, 189, 134),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Center(
                    child: Text(
                      isOwnDonation ? 'Not Allowed' : 'Add to Save',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cardo'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}