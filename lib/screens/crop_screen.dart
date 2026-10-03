import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class CropScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const CropScreen({super.key, required this.imageBytes});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обрежьте фото'),
        actions: [
          TextButton(
            onPressed: () {
              _controller.crop();
            },
            child: const Text('Готово', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
  children: [
    Expanded(
  child: Padding(
    padding: const EdgeInsets.all(40),
    child: Crop(
      image: widget.imageBytes,
      controller: _controller,
      aspectRatio: 1.0,
      onCropped: (result) {
        switch (result) {
          case CropSuccess(:final croppedImage):
            Navigator.pop(context, croppedImage);
          case CropFailure():
            Navigator.pop(context, null);
        }
      },
    ),
  ),
),
    Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _controller.crop(),
          icon: const Icon(Icons.check),
          label: const Text('Подтвердить'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ),
  ],
),
    );
  }
}