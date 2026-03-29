import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  static final TFLiteService _instance = TFLiteService._internal();

  late Interpreter _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;

  // Private constructor
  TFLiteService._internal();

  // Singleton factory
  factory TFLiteService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/mobilenetv2_tyre_model.tflite');
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (_labels.isEmpty) {
        throw Exception('Labels file is empty');
      }

      _isInitialized = true;
    } catch (e) {
      // ignore: avoid_print
      print("Failed to load model: $e");
      _isInitialized = false;
      rethrow;
    }
  }

  void close() {
    try {
      _interpreter.close();
      _isInitialized = false;
    } catch (e) {
      // ignore: avoid_print
      print("Error closing interpreter: $e");
    }
  }

  Future<String?> classifyImage(File imageFile) async {
    if (!_isInitialized) await initialize();

    try {
      // Validate image file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file not found');
      }

      final imageBytes = await imageFile.readAsBytes();
      img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception(
            'Failed to decode image. Please use a valid image format (JPG, PNG)');
      }

      // Resize image to model input size
      final img.Image resizedImage = img.copyResize(
        decodedImage,
        width: 224,
        height: 224,
      );

      // Prepare input tensor with proper normalization for MobileNetV2
      // MobileNetV2 expects input in range -1 to 1
      var input = List.generate(
        1,
        (i) => List.generate(
          224,
          (y) => List.generate(
            224,
            (x) => List.generate(3, (c) => 0.0),
          ),
        ),
      );

// Extract RGB channels, convert to BGR, and normalize
      // MobileNetV2's preprocess_input does RGB->BGR conversion and normalizes to -1..1
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixelSafe(x, y);

          // Extract RGB values - handle RGBA format
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          // Convert RGB to BGR and normalize to -1 to 1 range
          // This matches MobileNetV2's preprocess_input behavior
          input[0][y][x][0] = (b / 127.5) - 1.0; // B channel
          input[0][y][x][1] = (g / 127.5) - 1.0; // G channel
          input[0][y][x][2] =
              (r / 127.5) - 1.0; // R channel (swapped from first position)
        }
      }

      // Prepare output tensor - validate size matches labels count
      if (_labels.isEmpty) {
        throw Exception('No labels available for classification');
      }

      var output = List.generate(1, (i) => List.filled(_labels.length, 0.0));

      // Run inference
      try {
        _interpreter.run(input, output);
      } catch (e) {
        throw Exception(
            'Model inference failed: $e. Please ensure the model file is valid.');
      }

      // Post-process results
      final resultList = output[0];

      if (resultList.isEmpty) {
        throw Exception('No output from model');
      }

      double maxScore = -1.0;
      int maxIndex = -1;

      for (int i = 0; i < resultList.length; i++) {
        if (resultList[i] > maxScore) {
          maxScore = resultList[i];
          maxIndex = i;
        }
      }

      if (maxIndex == -1 || maxIndex >= _labels.length) {
        throw Exception('Invalid classification result');
      }

      String rawLabel = _labels[maxIndex].trim();

      // Labels are properly formatted from training (Accept, Reject, Repair)
      // Use them directly without transformation
      String mappedResult = rawLabel.isNotEmpty ? rawLabel : 'Unknown';

      return "$mappedResult (${(maxScore * 100).toStringAsFixed(1)}%)";
    } catch (e) {
      // ignore: avoid_print
      print("Error classifying image: $e");
      rethrow;
    }
  }
}
