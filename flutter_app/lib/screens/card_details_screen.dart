import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../theme.dart';

class CardDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> cardData;

  const CardDetailsScreen({super.key, required this.cardData});

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  late Set<String> _allDiscoveredTypes;
  late Set<String> _selectedTypes;
  bool _isFilterDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _initDiscoveredTypes();
  }

  void _initDiscoveredTypes() {
    final rawConditions = (widget.cardData['conditions'] as List?) ?? [];
    final types = <String>{};

    for (final cond in rawConditions) {
      final sales = (cond['sales'] as List?) ?? [];
      for (final sale in sales) {
        final t = extractSaleType(
          sale,
          condShort: cond['short']?.toString(),
          condLong: cond['long']?.toString(),
        );
        types.add(t);
      }
    }

    if (types.isEmpty) {
      types.add('Base');
    }

    const priority = {'Base': 0, 'Holo': 1, 'Reverse Holo': 2};
    final sortedList = types.toList()
      ..sort((a, b) {
        final pA = priority[a] ?? 10;
        final pB = priority[b] ?? 10;
        if (pA != pB) return pA.compareTo(pB);
        return a.compareTo(b);
      });

    _allDiscoveredTypes = sortedList.toSet();
    _selectedTypes = Set<String>.from(_allDiscoveredTypes);
  }

  static String extractSaleType(
    dynamic sale, {
    String? condShort,
    String? condLong,
  }) {
    final raw = (sale is Map ? (sale['type'] ?? '') : '').toString().trim();
    if (raw.isEmpty) return 'Base';

    String clean = raw;
    clean = clean.replaceAll('Reverse Holofoil', 'Reverse Holo');
    clean = clean.replaceAll('Rev Holo', 'Reverse Holo');
    clean = clean.replaceAll('Holofoil', 'Holo');

    final prefixes = <String>[
      if (condLong != null && condLong.trim().isNotEmpty) condLong.trim().toLowerCase(),
      if (condShort != null && condShort.trim().isNotEmpty) condShort.trim().toLowerCase(),
      'near mint', 'lightly played', 'moderately played', 'heavily played', 'damaged',
      'nm', 'lp', 'mp', 'hp', 'dmg',
    ];

    for (final prefix in prefixes) {
      if (clean.toLowerCase().startsWith(prefix)) {
        clean = clean.substring(prefix.length).trim();
        break;
      }
    }

    clean = clean.replaceFirst(RegExp(r'^[-/:\s.]+'), '').trim();

    if (clean.isEmpty) {
      return 'Base';
    }

    final lower = clean.toLowerCase();
    if (lower.startsWith('rev') || lower.contains('reverse')) {
      return 'Reverse Holo';
    }
    if (lower == 'holo' || lower == 'holofoil') {
      return 'Holo';
    }
    if (lower == 'base' || lower == 'normal') {
      return 'Base';
    }

    return clean;
  }

  int _countSalesForType(String type, List<dynamic> conditions) {
    int count = 0;
    for (final c in conditions) {
      final sales = (c['sales'] as List?) ?? [];
      for (final s in sales) {
        if (extractSaleType(
              s,
              condShort: c['short']?.toString(),
              condLong: c['long']?.toString(),
            ) ==
            type) {
          count++;
        }
      }
    }
    return count;
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedTypes = Set<String>.from(_allDiscoveredTypes);
    });
  }

  void _clearAll() {
    setState(() {
      _selectedTypes.clear();
    });
  }

  void _selectOnly(String type) {
    setState(() {
      _selectedTypes = {type};
    });
  }

  bool get _isFilterActive =>
      _selectedTypes.length != _allDiscoveredTypes.length;

  String get _filterButtonLabel {
    if (_selectedTypes.length == _allDiscoveredTypes.length) {
      return 'Type: All (${_allDiscoveredTypes.length})';
    } else if (_selectedTypes.isEmpty) {
      return 'Type: None (0)';
    } else if (_selectedTypes.length == 1) {
      return 'Type: ${_selectedTypes.first}';
    } else {
      return 'Type: ${_selectedTypes.length}/${_allDiscoveredTypes.length}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawConditions = (widget.cardData['conditions'] as List?) ?? [];

    final conditions = List<dynamic>.from(rawConditions);
    const conditionOrder = {
      'NM': 0,
      'LP': 1,
      'MP': 2,
      'HP': 3,
      'DMG': 4,
    };

    conditions.sort((a, b) {
      final aShort = a['short'] ?? '';
      final bShort = b['short'] ?? '';
      final aRank = conditionOrder[aShort] ?? 99;
      final bRank = conditionOrder[bShort] ?? 99;
      return aRank.compareTo(bRank);
    });

    return Scaffold(
      backgroundColor: HaloColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: HaloColors.background,
            title: Text(
              widget.cardData['name'] ?? 'Card Details',
              style: GoogleFonts.rajdhani(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: HaloColors.primary,
                letterSpacing: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (_allDiscoveredTypes.length > 1)
                IconButton(
                  icon: Icon(
                    Icons.filter_list,
                    color: _isFilterActive
                        ? HaloColors.secondary
                        : HaloColors.primary,
                  ),
                  tooltip: 'Filter by Type',
                  onPressed: () {
                    setState(() {
                      _isFilterDropdownOpen = !_isFilterDropdownOpen;
                    });
                  },
                ),
            ],
          ),

          // ── Card Info Section ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Card Image ──
                  if (widget.cardData['image_url'] != null &&
                      widget.cardData['image_url'].toString().isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: widget.cardData['image_url'],
                        width: 100,
                        height: 140,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 100,
                          height: 140,
                          decoration: BoxDecoration(
                            color: HaloColors.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: HaloColors.primary,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 100,
                          height: 140,
                          decoration: BoxDecoration(
                            color: HaloColors.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: HaloColors.textDim,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 100,
                      height: 140,
                      decoration: BoxDecoration(
                        color: HaloColors.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: HaloColors.border.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.style,
                        color: HaloColors.textDim,
                        size: 40,
                      ),
                    ),
                  const SizedBox(width: 16),

                  // ── Card Details ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          widget.cardData['name'] ?? 'Unknown Card',
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: HaloColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.cardData['num'] != null &&
                            widget.cardData['num'].toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.cardData['num'],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: HaloColors.secondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (widget.cardData['url'] != null &&
                            widget.cardData['url'].toString().isNotEmpty)
                          SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(
                                    'https://www.tcgplayer.com${widget.cardData['url']}');
                                await launchUrl(url,
                                    mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: Text(
                                'TCGPlayer',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: HaloColors.primary,
                                side: BorderSide(
                                  color: HaloColors.primary
                                      .withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(indent: 16, endIndent: 16),
          ),

          // ── Filter Bar Section ──
          if (_allDiscoveredTypes.length > 1) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    Text(
                      'CONDITIONS & SALES',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: HaloColors.textDim,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // ── Dropdown Button ──
                    InkWell(
                      onTap: () {
                        setState(() {
                          _isFilterDropdownOpen = !_isFilterDropdownOpen;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isFilterActive
                              ? HaloColors.primary.withValues(alpha: 0.15)
                              : HaloColors.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isFilterActive
                                ? HaloColors.primary
                                : HaloColors.border.withValues(alpha: 0.5),
                            width: _isFilterActive ? 1.0 : 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune,
                              size: 14,
                              color: _isFilterActive
                                  ? HaloColors.primary
                                  : HaloColors.textDim,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _filterButtonLabel,
                              style: GoogleFonts.rajdhani(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isFilterActive
                                    ? HaloColors.primary
                                    : HaloColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isFilterDropdownOpen
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              size: 18,
                              color: _isFilterActive
                                  ? HaloColors.primary
                                  : HaloColors.textDim,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Expanded Filter Dropdown Content ──
            if (_isFilterDropdownOpen)
              SliverToBoxAdapter(
                child: _buildFilterDropdown(conditions),
              ),
          ],

          // ── Content ──
          if (conditions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No pricing data found.',
                  style: TextStyle(color: HaloColors.textDim),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cond = conditions[index];
                    return _ConditionCard(
                      condition: cond,
                      isFirst: false,
                      selectedTypes: _selectedTypes,
                      allDiscoveredTypes: _allDiscoveredTypes,
                      onToggleType: _toggleType,
                    );
                  },
                  childCount: conditions.length,
                ),
              ),
            ),

          // ── Bottom padding ──
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(List<dynamic> conditions) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HaloColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isFilterActive
              ? HaloColors.primary.withValues(alpha: 0.6)
              : HaloColors.border.withValues(alpha: 0.4),
          width: _isFilterActive ? 1.0 : 0.5,
        ),
        boxShadow: _isFilterActive
            ? [
                BoxShadow(
                  color: HaloColors.primary.withValues(alpha: 0.08),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(Icons.tune, size: 14, color: HaloColors.primary),
              const SizedBox(width: 6),
              Text(
                'FILTER DISCOVERED TYPES',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: HaloColors.textDim,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _selectAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'ALL',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HaloColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _clearAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'CLEAR',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: HaloColors.textDim,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Discovered types list with checkboxes & counts
          ..._allDiscoveredTypes.map((type) {
            final isSelected = _selectedTypes.contains(type);
            final count = _countSalesForType(type, conditions);
            return InkWell(
              onTap: () => _toggleType(type),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (_) => _toggleType(type),
                        activeColor: HaloColors.primary,
                        checkColor: HaloColors.background,
                        side: BorderSide(
                          color: isSelected
                              ? HaloColors.primary
                              : HaloColors.textDim.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      type,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? HaloColors.textPrimary
                            : HaloColors.textDim,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: HaloColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: HaloColors.border.withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '$count sale${count == 1 ? '' : 's'}',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: HaloColors.textDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Quick presets
          if (_allDiscoveredTypes.length > 1) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Quick:',
                    style: GoogleFonts.rajdhani(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: HaloColors.textDim,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._allDiscoveredTypes.map((type) {
                    final isOnlyThis =
                        _selectedTypes.length == 1 && _selectedTypes.contains(type);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(
                          'Only $type',
                          style: GoogleFonts.rajdhani(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOnlyThis
                                ? HaloColors.background
                                : HaloColors.primary,
                          ),
                        ),
                        backgroundColor: isOnlyThis
                            ? HaloColors.primary
                            : HaloColors.primary.withValues(alpha: 0.1),
                        side: BorderSide(
                          color: HaloColors.primary
                              .withValues(alpha: isOnlyThis ? 1.0 : 0.3),
                          width: 0.5,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _selectOnly(type),
                      ),
                    );
                  }),
                  if (_allDiscoveredTypes.contains('Base') &&
                      _allDiscoveredTypes.length > 1)
                    ActionChip(
                      label: Text(
                        'No Base',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: HaloColors.secondary,
                        ),
                      ),
                      backgroundColor:
                          HaloColors.secondary.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: HaloColors.secondary.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _selectedTypes = _allDiscoveredTypes
                              .where((t) => t != 'Base')
                              .toSet();
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final dynamic condition;
  final bool isFirst;
  final Set<String> selectedTypes;
  final Set<String> allDiscoveredTypes;
  final Function(String type)? onToggleType;

  const _ConditionCard({
    required this.condition,
    this.isFirst = false,
    required this.selectedTypes,
    required this.allDiscoveredTypes,
    this.onToggleType,
  });

  @override
  Widget build(BuildContext context) {
    final rawSales = (condition['sales'] as List?) ?? [];
    final shortCode = condition['short'] ?? '?';
    final longName = condition['long'] ?? condition['short'] ?? 'Unknown';

    final filteredSales = rawSales.where((sale) {
      final t = _CardDetailsScreenState.extractSaleType(
        sale,
        condShort: shortCode,
        condLong: longName,
      );
      return selectedTypes.contains(t);
    }).toList();

    final isFiltered = selectedTypes.length < allDiscoveredTypes.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: HaloColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HaloColors.border.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: isFirst,
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),

          // ── Header ──
          leading: Container(
            width: 42,
            height: 28,
            decoration: BoxDecoration(
              color: HaloColors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: HaloColors.secondary.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Center(
              child: Text(
                shortCode,
                style: GoogleFonts.rajdhani(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: HaloColors.secondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          title: Text(
            longName,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: HaloColors.textPrimary,
            ),
          ),
          subtitle: Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: 13,
                color: HaloColors.textDim.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
              Text(
                isFiltered
                    ? '${filteredSales.length} of ${rawSales.length} sales'
                    : '${rawSales.length} recent sale${rawSales.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isFiltered ? HaloColors.primary : HaloColors.textDim,
                ),
              ),
            ],
          ),

          // ── Sales Table ──
          children: [
            const Divider(indent: 16, endIndent: 16),
            if (filteredSales.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  rawSales.isEmpty
                      ? 'No sales data.'
                      : 'No sales match the selected filter.',
                  style: GoogleFonts.inter(
                    color: HaloColors.textDim,
                    fontSize: 13,
                  ),
                ),
              )
            else ...[
              // Table header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _tableHeader('DATE', flex: 3),
                    _tableHeader('TYPE', flex: 2),
                    _tableHeader('QTY', flex: 1, align: TextAlign.center),
                    _tableHeader('PRICE', flex: 2, align: TextAlign.right),
                  ],
                ),
              ),
              const Divider(indent: 16, endIndent: 16, height: 1),

              // Table rows
              ...filteredSales.asMap().entries.map((entry) {
                final sale = entry.value;
                final isLast = entry.key == filteredSales.length - 1;
                return _SaleRow(
                  sale: sale,
                  shortCode: shortCode,
                  longName: longName,
                  isLast: isLast,
                );
              }),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _tableHeader(String text,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.rajdhani(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: HaloColors.textDim,
          letterSpacing: 1.5,
        ),
        textAlign: align,
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  final dynamic sale;
  final String shortCode;
  final String longName;
  final bool isLast;

  const _SaleRow({
    required this.sale,
    required this.shortCode,
    required this.longName,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayType = _CardDetailsScreenState.extractSaleType(
      sale,
      condShort: shortCode,
      condLong: longName,
    );

    Color typeColor = HaloColors.textPrimary;
    if (displayType == 'Reverse Holo') {
      typeColor = HaloColors.secondary;
    } else if (displayType == 'Holo') {
      typeColor = HaloColors.primary;
    } else if (displayType == 'Base') {
      typeColor = HaloColors.textDim;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: HaloColors.divider,
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        children: [
          // DATE — sky blue
          Expanded(
            flex: 3,
            child: Text(
              sale['date'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: HaloColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // TYPE — colored by variant
          Expanded(
            flex: 2,
            child: Text(
              displayType,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: typeColor,
                fontWeight:
                    displayType != 'Base' ? FontWeight.w500 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // QTY — dim
          Expanded(
            flex: 1,
            child: Text(
              sale['qty']?.toString() ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: HaloColors.textDim,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // PRICE — gold
          Expanded(
            flex: 2,
            child: Text(
              sale['price'] ?? '',
              style: GoogleFonts.rajdhani(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HaloColors.gold,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
