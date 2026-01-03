// File: lib/features/inm/widgets/inm_status_summary_card.dart
// Purpose: Simplified status card showing only EC values and status summary (for Dashboard tab)

import 'package:flutter/material.dart';

import '../models/inm_status.dart';
import '../services/inm_api_service.dart';

class InmStatusSummaryCard extends StatefulWidget {
  const InmStatusSummaryCard({super.key});

  @override
  State<InmStatusSummaryCard> createState() => _InmStatusSummaryCardState();
}

class _InmStatusSummaryCardState extends State<InmStatusSummaryCard> {
  final InmApiService _apiService = InmApiService();
  late Future<InmStatus> _statusFuture;

  @override
  void initState() {
    super.initState();
    _statusFuture = _apiService.fetchStatus();
  }

  void _refresh() {
    setState(() {
      _statusFuture = _apiService.fetchStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InmStatus>(
      future: _statusFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingCard();
        }
        
        if (snapshot.hasError) {
          return _buildErrorCard(snapshot.error.toString());
        }
        
        if (!snapshot.hasData) {
          return _buildErrorCard('No status data available');
        }
        
        return _buildStatusCard(snapshot.data!);
      },
    );
  }

  Widget _buildLoadingCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading INM Status...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load INM Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(InmStatus status) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(status.statusType);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with EC Status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getStatusIcon(status.statusType),
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'INM Status',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.statusLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Random Forest ML',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refresh,
                      tooltip: 'Refresh status',
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // EC Values Row
                Row(
                  children: [
                    Expanded(
                      child: _EcValueTile(
                        label: 'Current EC',
                        value: status.currentEc.toStringAsFixed(2),
                        unit: 'mS/cm',
                        icon: Icons.bolt,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _EcValueTile(
                        label: 'Predicted EC (24h)',
                        value: status.predictedEc24h.toStringAsFixed(2),
                        unit: 'mS/cm',
                        icon: status.isEcIncreasing ? Icons.trending_up : Icons.trending_down,
                        color: Colors.purple,
                        subtitle: '${status.ecChangePercent >= 0 ? '+' : ''}${status.ecChangePercent.toStringAsFixed(1)}%',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Single-line Status Summary
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: statusColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getStatusSummary(status),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusSummary(InmStatus status) {
    switch (status.statusType) {
      case EcStatusType.optimal:
        return 'All systems optimal — no action required';
      case EcStatusType.low:
        return 'EC slightly low — monitor closely';
      case EcStatusType.high:
        return 'EC slightly high — monitor closely';
      case EcStatusType.criticalLow:
        return 'EC critically low — action required';
      case EcStatusType.criticalHigh:
        return 'EC critically high — action required';
      case EcStatusType.unknown:
        return 'Status unknown — check sensors';
    }
  }

  Color _getStatusColor(EcStatusType status) {
    switch (status) {
      case EcStatusType.optimal:
        return Colors.green;
      case EcStatusType.low:
      case EcStatusType.high:
        return Colors.orange;
      case EcStatusType.criticalLow:
      case EcStatusType.criticalHigh:
        return Colors.red;
      case EcStatusType.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(EcStatusType status) {
    switch (status) {
      case EcStatusType.optimal:
        return Icons.check_circle;
      case EcStatusType.low:
        return Icons.arrow_downward;
      case EcStatusType.high:
        return Icons.arrow_upward;
      case EcStatusType.criticalLow:
      case EcStatusType.criticalHigh:
        return Icons.warning;
      case EcStatusType.unknown:
        return Icons.help_outline;
    }
  }
}

class _EcValueTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _EcValueTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


