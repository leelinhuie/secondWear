import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:untitled3/pages/show_clothes.dart';
import '../widgets/drawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/llma_api.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';


class UploadClothesPage extends StatefulWidget {
  @override
  _UploadClothesPageState createState() => _UploadClothesPageState();
}

class _UploadClothesPageState extends State<UploadClothesPage> {
  List<String> _imagePaths = [];
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _category;
  UploadTask? _uploadTask;
  bool _isUploading = false;
  final AIService _aiService = AIService();
  bool _isGeneratingDescription = false;
  LatLng? _selectedLocation;
  String? _addressText;
  final _addressController = TextEditingController();
  bool _isSearching = false;

  final List<String> _categories = [
    'None',
    'Shirts',
    'Pants',
    'Jackets',
    'Shoes',
    'Accessories'
  ];

  // Add a controller for keywords
  final _keywordsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print('Error getting location: $e');
    }
  }

Future<void> _pickImage() async {
  if (_imagePaths.length >= 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Maximum 5 images allowed')),
    );
    return;
  }
  final ImagePicker picker = ImagePicker();
  final XFile? image = await showDialog<XFile>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context, await picker.pickImage(source: ImageSource.camera));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Album'),
              onTap: () async {
                Navigator.pop(context, await picker.pickImage(source: ImageSource.gallery));
              },
            ),
          ],
        ),
      );
    },
  );

  if (image != null) {
    setState(() {
      _imagePaths.add(image.path);
    });
  }
}

  Future<void> _startUpload() async {
    if (_imagePaths.isEmpty) return;

    if (_titleController.text.isEmpty || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pickup location')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      List<String> downloadUrls = [];

      // Upload all images
      for (String imagePath in _imagePaths) {
        String fileName = path.basename(imagePath);
        File file = File(imagePath);
        Reference storageRef = FirebaseStorage.instance.ref().child('images/$fileName');
        
        setState(() {
          _uploadTask = storageRef.putFile(file);
        });

        TaskSnapshot taskSnapshot = await _uploadTask!.whenComplete(() {});
        String downloadUrl = await taskSnapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
      }

      // Generate a unique ID
      String clothesId = FirebaseFirestore.instance.collection('clothes').doc().id;

      // Save data to Firestore with all image URLs
      await FirebaseFirestore.instance.collection('clothes').doc(clothesId).set({
        'id': clothesId,
        'title': _titleController.text,
        'category': _category,
        'description': _descriptionController.text,
        'imageUrls': downloadUrls, // Store array of image URLs
        'uploadedAt': Timestamp.now(),
        'isApproved': false,
        'donorId': FirebaseAuth.instance.currentUser?.uid,
        'donorEmail': FirebaseAuth.instance.currentUser?.email,
        'pickupLocation': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'address': _addressText,
        },
      });

      // Show success message and navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload Complete!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DisplayClothesPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _generateDescription() async {
    if (_keywordsController.text.isEmpty || _category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter keywords and category')),
      );
      return;
    }

    setState(() {
      _isGeneratingDescription = true;
    });

    try {
      final description = await _aiService.generateDescription(
        _keywordsController.text,
        _category!,
      );
      
      setState(() {
        _descriptionController.text = description;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate description: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isGeneratingDescription = false;
      });
    }
  }

  Future<void> _searchLocation(Completer<GoogleMapController> mapController) async {
    setState(() {
      _isSearching = true;
    });
    
    try {
      List<Location> locations = await locationFromAddress(_addressController.text);
      if (locations.isNotEmpty) {
        final location = locations.first;
        final newPosition = LatLng(location.latitude, location.longitude);
        
        setState(() {
          _selectedLocation = newPosition;
          _addressText = _addressController.text;
        });

        final controller = await mapController.future;
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPosition,
              zoom: 15,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find the location')),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showLocationPicker() {
    final mapController = Completer<GoogleMapController>();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: const Text('Select Pickup Location'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        hintText: 'Enter address',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: () => _searchLocation(mapController),
                              ),
                      ),
                      onSubmitted: (_) => _searchLocation(mapController),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation ?? const LatLng(0, 0),
                      zoom: 15,
                    ),
                    onMapCreated: (controller) => mapController.complete(controller),
                    markers: _selectedLocation != null ? {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: _selectedLocation!,
                        infoWindow: InfoWindow(
                          title: 'Pickup Location',
                          snippet: _addressText ?? 'Selected Location',
                        ),
                      ),
                    } : {},
                    onTap: (LatLng location) async {
                      setState(() {
                        _selectedLocation = location;
                      });
                      
                      // Get address from coordinates
                      try {
                        List<Placemark> placemarks = await placemarkFromCoordinates(
                          location.latitude,
                          location.longitude,
                        );
                        if (placemarks.isNotEmpty) {
                          final place = placemarks.first;
                          final address = [
                            place.street,
                            place.subLocality,
                            place.locality,
                            place.postalCode,
                            place.country,
                          ].where((e) => e != null && e.isNotEmpty).join(', ');
                          
                          setState(() {
                            _addressText = address;
                            _addressController.text = address;
                          });
                        }
                      } catch (e) {
                        print('Error getting address: $e');
                      }
                    },
                  ),
                  if (_addressText != null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          _addressText!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.location_on),
          label: Text(_selectedLocation == null 
            ? 'Select Pickup Location' 
            : 'Location Selected'),
          onPressed: _showLocationPicker,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 200,
          child: _imagePaths.isEmpty
              ? GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: 50,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Add Photos",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length + 1, // +1 for add button
                  itemBuilder: (context, index) {
                    if (index == _imagePaths.length) {
                      // Add button at the end
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      );
                    }
                    
                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              File(_imagePaths[index]),
                              width: 150,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: Icon(
                              Icons.remove_circle,
                              color: Colors.red.shade700,
                            ),
                            onPressed: () {
                              setState(() {
                                _imagePaths.removeAt(index);
                              });
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
        if (_imagePaths.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              '${_imagePaths.length} photos selected',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        backgroundColor: const Color(0xFFC8DFC3),
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Donate Clothes",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontFamily: 'Cardo',
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageGallery(), // Replace the old image picker with new gallery
              const SizedBox(height: 24),
              Text(
                "Item Details",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: "Title",
                  labelStyle: TextStyle(color: Colors.green.shade700),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green.shade700),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                hint: const Text("Select Category"),
                decoration: InputDecoration(
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green.shade700),
                  ),
                ),
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category == 'None' ? null : category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _category = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _keywordsController,
                    decoration: InputDecoration(
                      labelText: "Keywords (e.g., blue cotton casual)",
                      labelStyle: TextStyle(color: Colors.green.shade700),
                      hintText: "Enter a few keywords about the item",
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green.shade700),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Scrollbar(
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: "Description",
                        labelStyle: TextStyle(color: Colors.green.shade700),
                        alignLabelWithHint: true,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.green.shade700),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      scrollController: ScrollController(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isGeneratingDescription ? null : _generateDescription,
                    icon: _isGeneratingDescription 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                            ),
                          )
                        : Icon(Icons.auto_awesome, color: Colors.green.shade700),
                    label: Text(
                      _isGeneratingDescription ? "Generating..." : "Generate Description",
                      style: TextStyle(color: Colors.green.shade700, fontFamily: 'OldStandardTT', fontSize: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildLocationSelector(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isUploading ? null : _startUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isUploading 
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text("Uploading..."),
                        ],
                      )
                    : const Text(
                      "Upload Item",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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