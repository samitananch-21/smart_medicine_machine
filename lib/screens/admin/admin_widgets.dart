import 'package:flutter/material.dart';

const adminInk = Color(0xff124c3c);
const adminMuted = Color(0xff668174);
const adminBackground = Color(0xffeff5f0);

class AdminSurface extends StatelessWidget {
  const AdminSurface({super.key, required this.child, this.padding = 22});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xffdce8df)),
        ),
        child: child,
      );
}

class AdminMessage extends StatelessWidget {
  const AdminMessage({super.key, required this.message, this.error = true});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: error ? const Color(0xfffff1ed) : const Color(0xffe9f5ed),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(error ? Icons.error_outline : Icons.info_outline,
                color: error ? const Color(0xffa73d29) : adminInk, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: error ? const Color(0xffa73d29) : adminInk,
                      height: 1.5)),
            ),
          ],
        ),
      );
}

class AdminTag extends StatelessWidget {
  const AdminTag({
    super.key,
    required this.label,
    this.color = adminInk,
    this.background = const Color(0xffeaf5ee),
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      );
}
