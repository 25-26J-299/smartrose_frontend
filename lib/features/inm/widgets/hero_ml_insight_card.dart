// File: lib/features/inm/widgets/hero_ml_insight_card.dart
// Purpose: Hero card showing ML prediction with severity and confidence

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/inm_status.dart';

class HeroMlInsightCard extends StatelessWidget {
  final InmStatus status;

  const HeroMlInsightCard({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(status.statusType);
    final severityLabel = _getSeverityLabel(status.statusType);
    final timeFormat = DateFormat('HH:mm');
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.8),
            statusColor.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.psychology,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ML Insight',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Main prediction message
                Text(
                  _getPredictionMessage(status),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Bottom info row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getSeverityIcon(status.statusType),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            severityLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Refreshed: ${timeFormat.format(status.timestamp ?? DateTime.now())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
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

  String _getPredictionMessage(InmStatus status) {
    switch (status.statusType) {
      case EcStatusType.optimal:
        return 'All systems optimal\nNo action needed 🌱';
      case EcStatusType.low:
        return 'EC slightly low\nMonitor closely 📊';
      case EcStatusType.high:
        return 'EC slightly high\nMonitor closely 📊';
      case EcStatusType.criticalLow:
        return 'EC critically low!\nImmediate action required ⚠️';
      case EcStatusType.criticalHigh:
        return 'EC critically high!\nImmediate action required ⚠️';
      case EcStatusType.unknown:
        return 'Status unknown\nCheck your sensors 🔧';
    }
  }

  String _getSeverityLabel(EcStatusType status) {
    switch (status) {
      case EcStatusType.optimal:
        return 'OPTIMAL';
      case EcStatusType.low:
      case EcStatusType.high:
        return 'WARNING';
      case EcStatusType.criticalLow:
      case EcStatusType.criticalHigh:
        return 'CRITICAL';
      case EcStatusType.unknown:
        return 'UNKNOWN';
    }
  }

  IconData _getSeverityIcon(EcStatusType status) {
    switch (status) {
      case EcStatusType.optimal:
        return Icons.check_circle;
      case EcStatusType.low:
      case EcStatusType.high:
        return Icons.info;
      case EcStatusType.criticalLow:
      case EcStatusType.criticalHigh:
        return Icons.warning;
      case EcStatusType.unknown:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(EcStatusType status) {
    switch (status) {
      case EcStatusType.optimal:
        return Colors.green.shade600;
      case EcStatusType.low:
      case EcStatusType.high:
        return Colors.orange.shade600;
      case EcStatusType.criticalLow:
      case EcStatusType.criticalHigh:
        return Colors.red.shade600;
      case EcStatusType.unknown:
        return Colors.grey.shade600;
    }
  }
}

