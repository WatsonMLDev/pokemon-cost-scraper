import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

class CardDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> cardData;

  const CardDetailsScreen({super.key, required this.cardData});

  @override
  Widget build(BuildContext context) {
    final conditions = (cardData['conditions'] as List?) ?? [];

    return Scaffold(
      backgroundColor: HaloColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: HaloColors.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                cardData['name'] ?? 'Card Details',
                style: GoogleFonts.rajdhani(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: HaloColors.primary,
                  letterSpacing: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      HaloColors.primary.withValues(alpha: 0.08),
                      HaloColors.background,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          if (conditions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('No pricing data found.',
                    style: TextStyle(color: HaloColors.textDim)),
              ),
            )
          else
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cond = conditions[index];
                    return _ConditionCard(
                      condition: cond,
                      isFirst: index == 0,
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
}

class _ConditionCard extends StatelessWidget {
  final dynamic condition;
  final bool isFirst;

  const _ConditionCard({required this.condition, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    final sales = (condition['sales'] as List?) ?? [];
    final shortCode = condition['short'] ?? '?';
    final longName = condition['long'] ?? condition['short'] ?? 'Unknown';

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
              Icon(Icons.receipt_long,
                  size: 13,
                  color: HaloColors.textDim.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                '${sales.length} recent sale${sales.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: HaloColors.textDim,
                ),
              ),
            ],
          ),

          // ── Sales Table ──
          children: [
            const Divider(indent: 16, endIndent: 16),
            if (sales.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No sales data.',
                    style: GoogleFonts.inter(
                        color: HaloColors.textDim, fontSize: 13)),
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
              ...sales.asMap().entries.map((entry) {
                final sale = entry.value;
                final isLast = entry.key == sales.length - 1;
                return _SaleRow(sale: sale, isLast: isLast);
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
  final bool isLast;

  const _SaleRow({required this.sale, this.isLast = false});

  @override
  Widget build(BuildContext context) {
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
          // TYPE — white
          Expanded(
            flex: 2,
            child: Text(
              sale['type'] ?? '',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: HaloColors.textPrimary,
              ),
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
