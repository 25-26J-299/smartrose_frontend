// File: lib/features/inm/screens/tabs/inm_recommendations_tab.dart
// Purpose: Recommendations tab - mobile-first decision and action focused page (2026 design)

import 'package:flutter/material.dart';

import '../../widgets/growth_stage_selector.dart';
import '../../services/inm_api_service.dart';
import '../../models/inm_status.dart';

class InmRecommendationsTab extends StatefulWidget {
  /// [deviceId] and [token] scope all API calls to the selected INM device.
  const InmRecommendationsTab({
    super.key,
    required this.deviceId,
    required this.token,
    this.onActionTaken,
  });

  final String deviceId;
  final String token;
  final VoidCallback? onActionTaken;

  @override
  State<InmRecommendationsTab> createState() => _InmRecommendationsTabState();
}

class _InmRecommendationsTabState extends State<InmRecommendationsTab>
    with AutomaticKeepAliveClientMixin {
  final InmApiService _apiService = InmApiService();
  late Future<List<dynamic>> _combinedFuture;
  bool _isActionTaken = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _combinedFuture = Future.wait([
      _apiService.fetchStatus(widget.deviceId, widget.token),
      _apiService.fetchGrowthStage(widget.deviceId, widget.token),
    ]);
  }

  @override
  bool get wantKeepAlive => true;

  void _refresh() {
    setState(() {
      _loadData();
      _isActionTaken = false;
    });
  }

  Future<void> _confirmAction(String type) async {
    final title = type == 'applied' ? 'Mark as Applied?' : 'Ignore Recommendation?';
    final message = type == 'applied' 
        ? 'Are you sure you want to mark these recommendations as applied?' 
        : 'Are you sure you want to skip these recommendations?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(type == 'applied' ? 'Applied' : 'Skip'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (type == 'applied') {
        _markAsApplied();
      } else {
        _skipRecommendations();
      }
    }
  }

  Future<void> _markAsApplied() async {
    final results = await _combinedFuture;
    final status = results[0] as InmStatus;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _apiService.saveAction(
          widget.deviceId, widget.token, status, 'applied');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isActionTaken = success;
        });

        if (success) {
          widget.onActionTaken?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✓ Action recorded and synced',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
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
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _skipRecommendations() async {
    final results = await _combinedFuture;
    final status = results[0] as InmStatus;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      final success = await _apiService.saveAction(
          widget.deviceId, widget.token, status, 'ignored');

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _isActionTaken = success;
        });

        if (success) {
          widget.onActionTaken?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Recommendation skipped',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
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
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return FutureBuilder<List<dynamic>>(
      future: _combinedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(theme, snapshot.error.toString());
        }

        if (!snapshot.hasData) {
          return _buildErrorState(theme, 'No data available');
        }

        final results = snapshot.data!;
        final status = results[0] as InmStatus;
        final growthStage = results[1] as String;
        
        return _buildContent(theme, status, growthStage);
      },
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load recommendations',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
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

  Widget _buildContent(ThemeData theme, InmStatus status, String currentGrowthStage) {
    // Only show actionable recommendations when the device has real sensor data
    final hasRecommendations = status.hasSensorData &&
        (status.ecAction.isNotEmpty ||
            status.phAction.isNotEmpty ||
            status.npkRecommendation.isNotEmpty);

    // Use currentGrowthStage if status.growthStage is null
    final displayGrowthStage = status.growthStage ?? currentGrowthStage;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Growth Stage Section
                GrowthStageSelector(
                  deviceId: widget.deviceId,
                  token: widget.token,
                ),
                
                const SizedBox(height: 20),
                
                // Recommendations
                if (hasRecommendations) ...[
                  // Priority: EC Action
                  if (status.ecAction.isNotEmpty) ...[
                    _CompactRecommendationCard(
                      title: 'EC Level',
                      recommendation: status.ecAction,
                      icon: Icons.electric_bolt,
                      color: Colors.purple,
                      statusType: status.statusType,
                      growthStage: displayGrowthStage,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // pH Action
                  if (status.phAction.isNotEmpty) ...[
                    _CompactRecommendationCard(
                      title: 'pH Balance',
                      recommendation: status.phAction,
                      icon: Icons.opacity,
                      color: Colors.teal,
                      statusType: EcStatusType.optimal, // pH usually not critical
                      growthStage: displayGrowthStage,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // NPK Recommendation - Split into N, P, K rows
                  if (status.npkRecommendation.isNotEmpty) ...[
                    _NpkRecommendationCard(
                      recommendation: status.npkRecommendation,
                      growthStage: displayGrowthStage,
                    ),
                  ],
                ] else ...[
                  // No sensor data vs. genuinely all good
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: status.hasSensorData
                          ? Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 64,
                                    color: Colors.green.shade600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'All Good!',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No actions needed at the moment.\nYour plants are thriving!',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sensors_off,
                                    size: 64,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No Sensor Data',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Waiting for data from the device.\nPlease ensure the device is connected and sending readings.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 80), // Space for bottom buttons
              ],
            ),
          ),
        ),
        
        // Action Buttons (fixed at bottom)
        if (hasRecommendations && !_isActionTaken)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _confirmAction('ignored'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : () => _confirmAction('applied'),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 20),
                      label: const Text('Mark as Applied'),
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
            ),
          ),
        
        // Action taken state
        if (_isActionTaken)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border(
                top: BorderSide(
                  color: Colors.green.shade200,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Action recorded successfully',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Compact recommendation card for EC/pH
class _CompactRecommendationCard extends StatefulWidget {
  final String title;
  final String recommendation;
  final IconData icon;
  final Color color;
  final EcStatusType statusType;
  final String? growthStage;

  const _CompactRecommendationCard({
    required this.title,
    required this.recommendation,
    required this.icon,
    required this.color,
    required this.statusType,
    this.growthStage,
  });

  @override
  State<_CompactRecommendationCard> createState() =>
      _CompactRecommendationCardState();
}

class _CompactRecommendationCardState
    extends State<_CompactRecommendationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = widget.statusType == EcStatusType.criticalLow ||
        widget.statusType == EcStatusType.criticalHigh;
    final isWarning = widget.statusType == EcStatusType.low ||
        widget.statusType == EcStatusType.high;

    // Parse recommendation into parts
    final parts = _parseRecommendation(widget.recommendation);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCritical
              ? widget.color.withOpacity(0.4)
              : widget.color.withOpacity(0.2),
          width: isCritical ? 2 : 1,
        ),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: widget.color.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isCritical)
                                _StatusChip(
                                  label: 'URGENT',
                                  color: Colors.red.shade600,
                                )
                              else if (isWarning)
                                _StatusChip(
                                  label: 'ATTENTION',
                                  color: Colors.orange.shade600,
                                )
                              else
                                _StatusChip(
                                  label: 'INFO',
                                  color: Colors.blue.shade600,
                                ),
                            ],
                          ),
                          if (widget.growthStage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'For: ${widget.growthStage![0].toUpperCase()}${widget.growthStage!.substring(1).toLowerCase()} Stage',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Headline
                Text(
                  parts['headline'] ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                
                // Primary action
                Text(
                  parts['action'] ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                  ),
                ),
                
                // Support line
                if (parts['support'] != null && parts['support']!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    parts['support']!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
                
                // Expandable technical details
                if (parts['technical'] != null &&
                    parts['technical']!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Row(
                      children: [
                        Icon(
                          _isExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isExpanded ? 'Less details' : 'More details',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isExpanded) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.color.withOpacity(0.15),
                        ),
                      ),
                      child: Text(
                        parts['technical']!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String?> _parseRecommendation(String rec) {
    // Extract first sentence as headline
    final sentences = rec.split('. ');
    String headline = sentences.isNotEmpty ? sentences[0] : '';
    
    // Try to extract action and support
    String action = '';
    String support = '';
    String technical = '';

    if (sentences.length > 1) {
      action = sentences[1];
      if (sentences.length > 2) {
        support = sentences[2];
      }
      if (sentences.length > 3) {
        technical = sentences.sublist(3).join('. ');
      }
    }

    return {
      'headline': headline,
      'action': action,
      'support': support,
      'technical': technical,
    };
  }
}

// NPK card with N, P, K rows
class _NpkRecommendationCard extends StatelessWidget {
  final String recommendation;
  final String? growthStage;

  const _NpkRecommendationCard({
    required this.recommendation,
    this.growthStage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final npkData = _parseNpkRecommendation(recommendation);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco, color: Colors.green, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nutrients (NPK)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (growthStage != null)
                          Text(
                            'For: ${growthStage![0].toUpperCase()}${growthStage!.substring(1).toLowerCase()} Stage',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                const Spacer(),
                _StatusChip(
                  label: 'INFO',
                  color: Colors.blue.shade600,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // N, P, K rows
          if (npkData['n'] != null) _NutrientRow(
            nutrient: 'Nitrogen (N)',
            recommendation: npkData['n']!,
            color: Colors.green,
          ),
          if (npkData['p'] != null) _NutrientRow(
            nutrient: 'Phosphorus (P)',
            recommendation: npkData['p']!,
            color: Colors.amber,
          ),
          if (npkData['k'] != null) _NutrientRow(
            nutrient: 'Potassium (K)',
            recommendation: npkData['k']!,
            color: Colors.pink,
          ),
        ],
      ),
    );
  }

  Map<String, String?> _parseNpkRecommendation(String rec) {
    final Map<String, String?> result = {'n': null, 'p': null, 'k': null};

    // Split by sentences
    final sentences = rec.split('. ');

    List<String> nSentences = [];
    List<String> pSentences = [];
    List<String> kSentences = [];
    String? currentNutrient;

    for (var sentence in sentences) {
      final lower = sentence.toLowerCase();
      
      // Check which nutrient this sentence belongs to
      if (lower.contains('nitrogen') || (lower.contains(' n ') && currentNutrient == 'n')) {
        currentNutrient = 'n';
        nSentences.add(sentence.trim());
      } else if (lower.contains('phosphorus') || (lower.contains(' p ') && currentNutrient == 'p')) {
        currentNutrient = 'p';
        pSentences.add(sentence.trim());
      } else if (lower.contains('potassium') || (lower.contains(' k ') && currentNutrient == 'k')) {
        currentNutrient = 'k';
        kSentences.add(sentence.trim());
      } else if (currentNutrient != null && sentence.trim().isNotEmpty) {
        // Continue with the current nutrient context
        if (currentNutrient == 'n') {
          nSentences.add(sentence.trim());
        } else if (currentNutrient == 'p') {
          pSentences.add(sentence.trim());
        } else if (currentNutrient == 'k') {
          kSentences.add(sentence.trim());
        }
      }
    }

    // Join sentences for each nutrient
    if (nSentences.isNotEmpty) {
      result['n'] = nSentences.take(2).join('. ') + '.';
    }
    if (pSentences.isNotEmpty) {
      result['p'] = pSentences.take(2).join('. ') + '.';
    }
    if (kSentences.isNotEmpty) {
      result['k'] = kSentences.take(2).join('. ') + '.';
    }

    return result;
  }
}

class _NutrientRow extends StatelessWidget {
  final String nutrient;
  final String recommendation;
  final Color color;

  const _NutrientRow({
    required this.nutrient,
    required this.recommendation,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Extract action from recommendation
    final parts = _extractAction(recommendation);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nutrient,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  parts['action'] ?? 'No action available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, String> _extractAction(String rec) {
    // Return the recommendation as-is (already parsed in parent)
    return {'action': rec};
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 9,
        ),
      ),
    );
  }
}
