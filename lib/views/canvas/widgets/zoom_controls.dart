import 'package:flutter/material.dart';

class ZoomControls extends StatelessWidget {
  final TransformationController transformationController;

  const ZoomControls({super.key, required this.transformationController});

  double get _currentScale => transformationController.value.getMaxScaleOnAxis();

  void _zoomTo(double targetScale) {
    final Matrix4 matrix = Matrix4.identity()..scale(targetScale);
    transformationController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transformationController,
      builder: (context, child) {
        final scale = _currentScale;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF252526),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white24),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                onPressed: () => _zoomTo((scale - 0.2).clamp(0.2, 2.5)),
              ),
              SizedBox(
                width: 110,
                child: Slider(
                  value: scale.clamp(0.2, 2.5),
                  min: 0.2,
                  max: 2.5,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => _zoomTo(val),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                onPressed: () => _zoomTo((scale + 0.2).clamp(0.2, 2.5)),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => _zoomTo(1.0),
                child: Text(
                  '${(scale * 100).toInt()}% Reset',
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
