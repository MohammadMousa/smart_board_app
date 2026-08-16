import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/board_provider.dart';
import 'views/canvas/canvas_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BoardProvider()),
      ],
      child: const SmartBoardApp(),
    ),
  );
}

class SmartBoardApp extends StatelessWidget {
  const SmartBoardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
        ),
      ),
      home: const CanvasScreen(),
    );
  }
}