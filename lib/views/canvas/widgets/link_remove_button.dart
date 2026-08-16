import 'package:flutter/material.dart';

class LinkRemoveButton extends StatelessWidget {
  final VoidCallback onTap;

  const LinkRemoveButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        alignment: Alignment.center, // Strictly centers the child icon
        decoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
            ),
          ],
        ),
        child: const Icon(
          Icons.delete_outline,
          size: 12, // Scaled down to sit cleanly inside 20x20 container
          color: Colors.white,
        ),
      ),
    );
  }
}