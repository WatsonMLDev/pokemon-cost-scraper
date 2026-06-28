import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';
import 'processing_screen.dart';
import 'scraping_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  final List<dynamic> results;

  const SearchResultsScreen({
    super.key,
    required this.query,
    required this.results,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String newQuery) {
    if (newQuery.trim().isEmpty) return;
    Navigator.pushReplacement(
      context,
      _haloPageRoute(
        ProcessingScreen(textQuery: newQuery.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HaloColors.background,
      appBar: AppBar(
        title: Text('Select a Card',
            style: GoogleFonts.rajdhani(
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            )),
      ),
      body: widget.results.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 64,
                      color: HaloColors.textDim.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('No results found.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            )
          : Column(
              children: [
                // ── Edit Search Bar ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Refine search...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: HaloColors.card.withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: HaloColors.primary.withValues(alpha: 0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: HaloColors.primary.withValues(alpha: 0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: HaloColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: HaloColors.primary),
                        onPressed: () => _submitSearch(_searchController.text),
                      ),
                    ),
                    onSubmitted: _submitSearch,
                  ),
                ),
                
                // ── Result count badge ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: HaloColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: HaloColors.primary.withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          '${widget.results.length} FOUND',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: HaloColors.primary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Tap to select',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // ── Results List ──
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: widget.results.length,
                    itemBuilder: (context, index) {
                      final item = widget.results[index];
                      return _SearchResultTile(
                        item: item,
                        index: index,
                        onTap: () {
                          Navigator.push(
                            context,
                            _haloPageRoute(
                              ScrapingScreen(item: item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _SearchResultTile extends StatefulWidget {
  final dynamic item;
  final int index;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  State<_SearchResultTile> createState() => _SearchResultTileState();
}

class _SearchResultTileState extends State<_SearchResultTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _controller.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _controller.reverse();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _isPressed
                ? HaloColors.primary.withValues(alpha: 0.08)
                : HaloColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isPressed
                  ? HaloColors.primary.withValues(alpha: 0.4)
                  : HaloColors.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // ── Index number ──
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: HaloColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: HaloColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Left accent bar ──
                Container(
                  width: 2,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        HaloColors.primary,
                        HaloColors.primary.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Card info ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item['name'] ?? '',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: HaloColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.item['num'] != null &&
                          widget.item['num'].toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.item['num'],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: HaloColors.secondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Arrow ──
                Icon(
                  Icons.chevron_right,
                  color: HaloColors.textDim.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
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
