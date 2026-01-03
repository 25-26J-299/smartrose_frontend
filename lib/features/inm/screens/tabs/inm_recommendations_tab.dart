// File: lib/features/inm/screens/tabs/inm_recommendations_tab.dart
// Purpose: Recommendations tab - decision and action focused page

import 'package:flutter/material.dart';

import '../../widgets/growth_stage_selector.dart';
import '../../services/inm_api_service.dart';
import '../../models/inm_status.dart';

class InmRecommendationsTab extends StatefulWidget {
  const InmRecommendationsTab({super.key});

  @override
  State<InmRecommendationsTab> createState() => _InmRecommendationsTabState();
}

class _InmRecommendationsTabState extends State<InmRecommendationsTab> with AutomaticKeepAliveClientMixin {
  final InmApiService _apiService = InmApiService();
  late Future<InmStatus> _statusFuture;
  bool _isActionTaken = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = _apiService.fetchStatus();
  }

  @override
  bool get wantKeepAlive => true;

  void _refresh() {
    setState(() {
      _statusFuture = _apiService.fetchStatus();
      _isActionTaken = false;
    });
  }

  Future<void> _markAsApplied() async {
    // Get current status to save with action
    final status = await _statusFuture;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Save action to backend
      final success = await _apiService.saveAction(status, 'applied');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isActionTaken = success;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recommendations marked as applied',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to save action. Please try again.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _ignoreRecommendations() async {
    // Get current status to save with action
    final status = await _statusFuture;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Save action to backend
      final success = await _apiService.saveAction(status, 'ignored');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isActionTaken = success;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recommendations ignored',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to save action. Please try again.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _statusFuture;
      },
      child: FutureBuilder<InmStatus>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          }
          
          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          }
          
          if (!snapshot.hasData) {
            return _buildErrorState('No recommendations available');
          }
          
          return _buildMainContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading recommendations...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load recommendations',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
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

  Widget _buildMainContent(InmStatus status) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Growth Stage Section (top)
          const GrowthStageSelector(),
          const SizedBox(height: 24),
          
          // 2. Main Recommendation Card (primary focus)
          _buildMainRecommendationCard(status),
          const SizedBox(height: 24),
          
          // 3. Action Taken Buttons (bottom)
          _buildActionButtons(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMainRecommendationCard(InmStatus status) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(status.statusType);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.recommend,
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
                        'Recommended Actions',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (status.growthStage != null && status.growthStage!.isNotEmpty) ...[
                            Icon(
                              Icons.eco,
                              size: 14,
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_capitalizeStage(status.growthStage!)} stage',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.psychology,
                            size: 14,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
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
                  tooltip: 'Refresh recommendations',
                ),
              ],
            ),
          ),
          
          // Recommendations Content (prioritize EC > pH > NPK)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // EC Action (Primary - Most Important)
                _RecommendationTile(
                  icon: Icons.electric_bolt,
                  title: 'EC Action',
                  content: status.ecAction,
                  color: statusColor,
                  isPrimary: true,
                ),
                
                const SizedBox(height: 16),
                
                // pH Action
                _RecommendationTile(
                  icon: Icons.water_drop,
                  title: 'pH Action',
                  content: status.phAction,
                  color: Colors.teal,
                ),
                
                const SizedBox(height: 16),
                
                // NPK Recommendation
                _RecommendationTile(
                  icon: Icons.eco,
                  title: 'NPK Recommendation',
                  content: status.npkRecommendation,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    
    if (_isActionTaken) {
      return Card(
        elevation: 2,
        color: Colors.green.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Action recorded successfully',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _ignoreRecommendations,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close),
            label: const Text('Ignore'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: theme.colorScheme.outline,
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _markAsApplied,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('Mark as Applied'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
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

  String _capitalizeStage(String stage) {
    if (stage.isEmpty) return stage;
    return stage[0].toUpperCase() + stage.substring(1).toLowerCase();
  }
}

class _RecommendationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;
  final bool isPrimary;

  const _RecommendationTile({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isPrimary ? 20 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(isPrimary ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isPrimary ? 0.3 : 0.2),
          width: isPrimary ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isPrimary ? 8 : 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isPrimary ? 20 : 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: isPrimary ? 16 : null,
                  ),
                ),
              ),
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PRIORITY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.85),
              height: 1.5,
              fontSize: isPrimary ? 15 : null,
            ),
          ),
        ],
      ),
    );
  }
}

