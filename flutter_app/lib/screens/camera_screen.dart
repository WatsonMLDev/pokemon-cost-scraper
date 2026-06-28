import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/tactical_overlay.dart';
import 'processing_screen.dart';


class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  late AnimationController _pulseController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    if (widget.cameras.isNotEmpty) {
      _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
      }).catchError((Object e) {
        if (e is CameraException) {
          debugPrint('Camera Error: ${e.code}\n${e.description}');
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    try {
      final XFile image = await _controller!.takePicture();
      if (!mounted) return;

      Navigator.push(
        context,
        _haloPageRoute(
          ProcessingScreen(imageFile: File(image.path)),
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: HaloColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined,
                  size: 64, color: HaloColors.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('Initializing camera...',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HaloColors.background,
      body: Stack(
        children: [
          // ── Camera Preview ──
          Positioned.fill(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // ── Tactical Reticle Overlay ──
          const Positioned.fill(
            child: TacticalOverlay(),
          ),

          // ── Scanline Animation ──
          const Positioned.fill(
            child: ScanlineOverlay(opacity: 0.04),
          ),

          // ── Top Gradient & Search Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HaloColors.background.withValues(alpha: 0.95),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Manual Search...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            filled: true,
                            fillColor: HaloColors.card.withValues(alpha: 0.6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: HaloColors.primary.withValues(alpha: 0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide(color: HaloColors.primary.withValues(alpha: 0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: const BorderSide(color: HaloColors.primary),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search, color: HaloColors.primary),
                              onPressed: () {
                                if (_searchController.text.trim().isNotEmpty) {
                                  Navigator.push(
                                    context,
                                    _haloPageRoute(
                                      ProcessingScreen(textQuery: _searchController.text.trim()),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              Navigator.push(
                                context,
                                _haloPageRoute(
                                  ProcessingScreen(textQuery: value.trim()),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),


          // ── Bottom Gradient ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 160,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    HaloColors.background.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Capture Button ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final pulseValue =
                      0.85 + (_pulseController.value * 0.15);
                  return GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: HaloColors.primary
                              .withValues(alpha: pulseValue),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: HaloColors.primary
                                .withValues(alpha: pulseValue * 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                HaloColors.primary.withValues(alpha: 0.3),
                                HaloColors.primary.withValues(alpha: 0.1),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: HaloColors.primary,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom page route with slide + fade transition.
PageRouteBuilder<T> _haloPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}
