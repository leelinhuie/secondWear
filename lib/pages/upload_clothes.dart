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
  String? _imagePath;
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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _imagePath = image.path;
      });
    }
  }

  Future<void> _startUpload() async {
    if (_imagePath == null) return;

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
      // Upload image
      String fileName = path.basename(_imagePath!);
      File file = File(_imagePath!);
      Reference storageRef = FirebaseStorage.instance.ref().child('images/$fileName');
      
      setState(() {
        _uploadTask = storageRef.putFile(file);
      });

      TaskSnapshot taskSnapshot = await _uploadTask!.whenComplete(() {});
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Generate a unique ID
      String clothesId = FirebaseFirestore.instance.collection('clothes').doc().id;

      // Save data to Firestore with donor information
      await FirebaseFirestore.instance.collection('clothes').doc(clothesId).set({
        'id': clothesId,
        'title': _titleController.text,
        'category': _category,
        'description': _descriptionController.text,
        'imageUrl': downloadUrl,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: DrawerMenu(),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Donate Clothes",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
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
                  child: _imagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Take a Photo",
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),
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
                  TextField(
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
                      style: TextStyle(color: Colors.green.shade700),
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
