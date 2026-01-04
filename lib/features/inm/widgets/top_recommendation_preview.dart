// File: lib/features/inm/widgets/top_recommendation_preview.dart
// Purpose: Preview of the most important recommendation with CTA

import 'package:flutter/material.dart';

import '../models/inm_status.dart';

class TopRecommendationPreview extends StatelessWidget {
  final InmStatus status;
  final VoidCallback onViewRecommendations;

  const TopRecommendationPreview({
    super.key,
    required this.status,
    required this.onViewRecommendations,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topRecommendation = _getTopRecommendation(status);
    
    if (topRecommendation.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lightbulb,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Top Recommendation',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_isPriority(status))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'URGENT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 14),
          
          // Recommendation text (truncated)
          Text(
            _truncateText(topRecommendation, 80),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 16),
          
          // CTA Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onViewRecommendations,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('View All Recommendations'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTopRecommendation(InmStatus status) {
    // Priority: EC > pH > NPK
    if (status.ecAction.isNotEmpty) {
      return status.ecAction;
    }
    if (status.phAction.isNotEmpty) {
      return status.phAction;
    }
    if (status.npkRecommendation.isNotEmpty) {
      return status.npkRecommendation;
    }
    return '';
  }

  bool _isPriority(InmStatus status) {
    return status.statusType == EcStatusType.criticalLow ||
        status.statusType == EcStatusType.criticalHigh;
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

