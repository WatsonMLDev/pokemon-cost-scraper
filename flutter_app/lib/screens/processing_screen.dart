import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../theme.dart';
import '../widgets/glassmorphic_card.dart';
import 'search_results_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final File imageFile;

  const ProcessingScreen({super.key, required this.imageFile});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen>
    with TickerProviderStateMixin {
  String _status = "Uploading image...";
  List<dynamic>? _results;
  String? _error;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _uploadAndSearch();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _uploadAndSearch() async {
    try {
      final String baseUrl = dotenv.env['API_BASE_URL'] ?? "http://127.0.0.1:8000";
      final String token = dotenv.env['API_KEY'] ?? "";

      final request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/api/v1/search_by_image'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files
          .add(await http.MultipartFile.fromPath('file', widget.imageFile.path));

      final response = await request.send();

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim().isEmpty) return;
          final data = jsonDecode(line);
          if (!mounted) return;

          setState(() {
            if (data['type'] == 'status') {
              _status = data['message'];
            } else if (data['type'] == 'error') {
              _error = data['message'];
            } else if (data['type'] == 'result') {
              _results = data['data']['search_items'];
              Navigator.pushReplacement(
                context,
                _haloPageRoute(
                  SearchResultsScreen(results: _results!),
                ),
              );
            }
          });
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _error = e.toString();
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.background,
      appBar: AppBar(
        title: Text('Scanning',
            style: GoogleFonts.rajdhani(
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            )),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_error != null) ...[
                  // ── Error State ──
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: HaloColors.danger.withValues(alpha: 0.5),
                          width: 2),
                    ),
                    child: const Icon(Icons.error_outline,
                        color: HaloColors.danger, size: 40),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _error!,
                    style: GoogleFonts.inter(
                        color: HaloColors.danger, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back to Camera'),
                  ),
                ] else ...[
                  // ── Loading State ──
                  const HaloSpinner(size: 100),
                  const SizedBox(height: 40),
                  _AnimatedStatusText(status: _status),
                  const SizedBox(height: 16),
                  Text(
                    'Analyzing your card...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Status text that fades when it changes.
class _AnimatedStatusText extends StatefulWidget {
  final String status;
  const _AnimatedStatusText({required this.status});

  @override
  State<_AnimatedStatusText> createState() => _AnimatedStatusTextState();
}

class _AnimatedStatusTextState extends State<_AnimatedStatusText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String _displayedText = '';

  @override
  void initState() {
    super.initState();
    _displayedText = widget.status;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedStatusText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reverse().then((_) {
        if (!mounted) return;
        setState(() => _displayedText = widget.status);
        _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Text(
        _displayedText,
        style: GoogleFonts.rajdhani(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: HaloColors.primary,
          letterSpacing: 1.0,
        ),
        textAlign: TextAlign.center,
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
