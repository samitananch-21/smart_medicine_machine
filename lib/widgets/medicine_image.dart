import 'package:flutter/material.dart';
import '../models/medicine.dart';

class MedicineImage extends StatelessWidget {
  const MedicineImage({super.key, required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      medicine.image,
      fit: BoxFit.contain,
      semanticLabel: medicine.name,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.medication_outlined, size: 64, color: Colors.green),
      ),
    );
  }
}
