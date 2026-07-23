// lib/shared/widgets/obra_mini_card.dart
import 'package:flutter/material.dart';
import 'gd_card.dart';
import 'app_theme.dart';
import 'gd_card.dart';
class ObraMiniCard extends StatelessWidget {
  final int index;
  const ObraMiniCard({super.key, required this.index});

  static const _obras = [
    ('Residência Vila Nova', 'Piracicaba, SP', 'em_andamento', 0.62),
    ('Galpão Industrial', 'Limeira, SP', 'em_andamento', 0.38),
    ('Cond. Jardins do Sol', 'Piracicaba, SP', 'em_andamento', 0.85),
    ('Casa Térrea', 'Rio Claro, SP', 'planejamento', 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    final (nome, local, status, progresso) = _obras[index % _obras.length];
    final color = AppTheme.statusColor(status);

    return GDCard(
      gradient: AppTheme.cardGradient,
      padding: const EdgeInsets.all(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(
              child: Icon(Icons.construction_rounded,
                size: 36, color: AppTheme.cardBorder,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 13,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                      size: 11, color: AppTheme.textMuted,
                    ),
                    const SizedBox(width: 2),
                    Text(local, style: const TextStyle(
                      fontSize: 11, color: AppTheme.textMuted,
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(AppTheme.statusLabel(status),
                        style: TextStyle(
                          color: color, fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text('${(progresso * 100).toInt()}%',
                      style: TextStyle(
                        color: color, fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
