import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// A metric card widget that displays a key performance indicator with an icon,
/// title, value, and description. Based on the design shown in the dashboard.
/// 
/// Example usage:
/// ```dart
/// MetricCard(
///   title: 'Distinct Roles',
///   value: '3',
///   description: 'Your description here',
///   icon: Icons.category_outlined,
///   color: Colors.green,
/// )
/// ```
class MetricCard extends StatelessWidget {
  /// The title displayed at the top of the card
  final String title;
  
  /// The main value displayed prominently in the card
  final String value;
  
  /// The description text displayed below the value
  final String description;
  
  /// The icon displayed in the colored square container
  final IconData icon;
  
  /// The primary color theme for the card (affects icon background and value color)
  final Color color;
  
  /// Optional callback when the card is tapped
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 18 : 24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.3),
                width: 0.9,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon container with colored background
                Container(
                  width: isMobile ? 48 : 56,
                  height: isMobile ? 48 : 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: isMobile ? 24 : 28,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Title
                Text(
                  title,
                  style: AppTheme.bodyMedium.copyWith(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Value (large and bold)
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                
                // Description
                Text(
                  description,
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: isMobile ? 11 : 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal row of metric cards, typically used for dashboard statistics.
/// 
/// Example usage:
/// ```dart
/// MetricCardsRow(
///   cards: [
///     MetricCardData(
///       title: 'Distinct Roles',
///       value: '3',
///       description: 'Your description here',
///       icon: Icons.category_outlined,
///       color: Colors.green,
///     ),
///     MetricCardData(
///       title: 'Total Users',
///       value: '10',
///       description: 'accounts currently managed',
///       icon: Icons.people_outline,
///       color: Colors.purple,
///     ),
///     MetricCardData(
///       title: 'Active Ratio',
///       value: '80.0%',
///       description: 'of users are currently active',
///       icon: Icons.trending_up,
///       color: Colors.blue,
///     ),
///   ],
/// )
/// ```
class MetricCardsRow extends StatelessWidget {
  /// List of metric card data to display
  final List<MetricCardData> cards;
  
  /// Spacing between cards
  final double spacing;

  const MetricCardsRow({
    super.key,
    required this.cards,
    this.spacing = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    
    if (isMobile) {
      // On mobile, show cards in a column
      return Column(
        children: cards.asMap().entries.map((entry) {
          final index = entry.key;
          final cardData = entry.value;
          return Padding(
            padding: EdgeInsets.only(
              bottom: index < cards.length - 1 ? spacing : 0,
            ),
            child: MetricCard(
              title: cardData.title,
              value: cardData.value,
              description: cardData.description,
              icon: cardData.icon,
              color: cardData.color,
              onTap: cardData.onTap,
            ),
          );
        }).toList(),
      );
    }
    
    // On desktop/tablet, show cards in a row
    return Row(
      children: cards.asMap().entries.map((entry) {
        final index = entry.key;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index < cards.length - 1 ? spacing : 0,
            ),
            child: MetricCard(
              title: entry.value.title,
              value: entry.value.value,
              description: entry.value.description,
              icon: entry.value.icon,
              color: entry.value.color,
              onTap: entry.value.onTap,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Data class for metric card information
class MetricCardData {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const MetricCardData({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

