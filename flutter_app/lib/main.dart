import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'theme.dart';
import 'screens/camera_screen.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error getting cameras: $e');
  }
  runApp(const PokemonScraperApp());
}

class PokemonScraperApp extends StatelessWidget {
  const PokemonScraperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokemon Scraper',
      debugShowCheckedModeBanner: false,
      theme: buildHaloTheme(),
      home: CameraScreen(cameras: cameras),
    );
  }
}
