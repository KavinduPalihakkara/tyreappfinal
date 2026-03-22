import 'dart:io';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteService {
  late Interpreter _interpreter;
  List<String> _labels = [];

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilenetv2_tyre_model.tflite');
      final labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _isInitialized = true;
    } catch (e) {
      // ignore: avoid_print
      print("Failed to load model: $e");
    }
  }

  Future<String?> classifyImage(File imageFile) async {
    if (!_isInitialized) await initialize();

    final imageBytes = await imageFile.readAsBytes();
    img.Image? decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) return null;

    final img.Image resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

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

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[0][y][x][0] = (pixel.r / 127.5) - 1.0;
        input[0][y][x][1] = (pixel.g / 127.5) - 1.0;
        input[0][y][x][2] = (pixel.b / 127.5) - 1.0;
      }
    }

    var output = List.generate(1, (i) => List.filled(_labels.length, 0.0));

    try {
      _interpreter.run(input, output);
    } catch (e) {
      // ignore: avoid_print
      print("Error running inference: $e");
      return null;
    }

    final resultList = output[0];
    double maxScore = -1.0;
    int maxIndex = -1;

    for (int i = 0; i < resultList.length; i++) {
      if (resultList[i] > maxScore) {
        maxScore = resultList[i];
        maxIndex = i;
      }
    }

    if (maxIndex != -1) {
      String rawLabel = _labels[maxIndex].trim();
      
      String mappedResult = rawLabel.isNotEmpty 
          ? '${rawLabel[0].toUpperCase()}${rawLabel.substring(1).toLowerCase()}' 
          : rawLabel;
          
      // Ensure 'repair', 'repar', or 'repir' is spelled correctly as 'Repair' in the UI
      if (mappedResult.toLowerCase() == 'repair' || mappedResult.toLowerCase() == 'repar' || mappedResult.toLowerCase() == 'repir') {
        mappedResult = 'Repair';
      } else if (mappedResult.toLowerCase() == 'accept') {
        mappedResult = 'Acceptable'; // Display as Acceptable for better UX if desired, or keep as Accept.
      } else if (mappedResult.toLowerCase() == 'reject') {
        mappedResult = 'Reject';
      }

      return "$mappedResult (${(maxScore * 100).toStringAsFixed(1)}%)";
    }

    return null;
  }
}
