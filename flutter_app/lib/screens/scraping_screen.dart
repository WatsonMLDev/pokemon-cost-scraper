import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../theme.dart';
import '../widgets/glassmorphic_card.dart';
import 'card_details_screen.dart';

class ScrapingScreen extends StatefulWidget {
  final dynamic item;

  const ScrapingScreen({super.key, required this.item});

  @override
  State<ScrapingScreen> createState() => _ScrapingScreenState();
}

class _ScrapingScreenState extends State<ScrapingScreen> {
  String _status = "Starting scraper...";
  Map<String, dynamic>? _cardData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrapeData();
  }

  Future<void> _scrapeData() async {
    try {
      final String baseUrl = dotenv.env['API_BASE_URL'] ?? "http://127.0.0.1:8000";
      final String token = dotenv.env['API_KEY'] ?? "";

      final request = http.Request(
          'POST', Uri.parse('$baseUrl/api/v1/scrape_card'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';
      request.body = jsonEncode({
        "url": widget.item['url'],
        "name": widget.item['name'],
      });

      final response = await http.Client().send(request);

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
              _cardData = data['data'];
              Navigator.pushReplacement(
                context,
                _haloPageRoute(
                  CardDetailsScreen(cardData: _cardData!),
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
        title: Text(
          widget.item['name'] ?? 'Scraping',
          style: GoogleFonts.rajdhani(
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null) ...[
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
                  style:
                      GoogleFonts.inter(color: HaloColors.danger, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ] else ...[
                const HaloSpinner(size: 100),
                const SizedBox(height: 40),
                Text(
                  _status,
                  style: GoogleFonts.rajdhani(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: HaloColors.primary,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Fetching pricing data...',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
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
