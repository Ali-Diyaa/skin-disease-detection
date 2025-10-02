import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Skin Disease Detection",
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      home: const ObjectDetectionScreen(),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  const ObjectDetectionScreen({super.key});

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  File? file;
  var _recognitions;
  var v = "";

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    await Tflite.loadModel(
      model: "assets/skin_disease_model.tflite",
      labels: "assets/labels.txt",
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _image = image;
        file = File(image.path);
      });

      detectImage(file!);
    } catch (e) {
      log('Error picking image: $e');
    }
  }

  Future<void> detectImage(File image) async {
    try {
      img.Image? imageBytes = img.decodeImage(image.readAsBytesSync());
      if (imageBytes == null) {
        log('Failed to decode image.');
        return;
      }

      if (imageBytes.numChannels == 4) {
        imageBytes = convertRgbaToRgb(imageBytes);
      }

      img.Image resizedImage =
          img.copyResize(imageBytes, width: 256, height: 256);

      final tempDir = Directory.systemTemp;
      final tempPath = '${tempDir.path}/temp_image.jpg';
      File resizedFile = File(tempPath)
        ..writeAsBytesSync(img.encodeJpg(resizedImage));

      var recognitions = await Tflite.runModelOnImage(
        path: resizedFile.path,
        numResults: 7,
        threshold: 0.05,
        imageMean: 127.5,
        imageStd: 127.5,
      );

      setState(() {
        _recognitions = recognitions;
        v = recognitions.toString();
      });

      log('Recognitions: $_recognitions');
    } catch (e) {
      log('Error detecting image: $e');
    }
  }

  img.Image convertRgbaToRgb(img.Image rgbaImage) {
    final rgbImage = img.Image(width: rgbaImage.width, height: rgbaImage.height);
    for (int y = 0; y < rgbaImage.height; y++) {
      for (int x = 0; x < rgbaImage.width; x++) {
        final pixel = rgbaImage.getPixel(x, y);
        rgbImage.setPixelRgb(x, y, pixel.r, pixel.g, pixel.b);
      }
    }
    return rgbImage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        toolbarHeight: 80,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
        title: const Text(
          '🩺 Skin Disease Detector',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                if (_image != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      File(_image!.path),
                      height: 250,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: Text(
                        '📷 Pick an image to identify',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ),
                const SizedBox(height: 40),

                // Pick Image Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    backgroundColor: Colors.deepPurple,
                    shadowColor: Colors.deepPurpleAccent,
                    elevation: 8,
                  ),
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image, color: Colors.white),
                  label: const Text(
                    "Pick Image from Gallery",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 30),

                // Results
                if (v.isNotEmpty)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 6,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        v,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ),
                  )
                else
                  const Text(
                    "⚡ No prediction yet",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
