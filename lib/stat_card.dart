// lib/shared/widgets/stat_card.dart
import 'package:flutter/material.dart';
import 'gd_card.dart';
import 'app_theme.dart';
import 'gd_card.dart';

class StatCard extends StatelessWidget {
  final dynamic kpi;
  const StatCard({super.key, required this.kpi});

  @override
  Widget build(BuildContext context) {
    return GDCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (kpi.color as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(kpi.icon as IconData,
              color: kpi.color as Color, size: 18,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(kpi.value as String,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: kpi.color as Color,
                ),
              ),
              Text(kpi.label as String,
                style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
