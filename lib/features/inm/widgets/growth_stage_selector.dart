// File: lib/features/inm/widgets/growth_stage_selector.dart
// Purpose: Widget for selecting and saving growth stage

import 'package:flutter/material.dart';

import '../services/inm_api_service.dart';

class GrowthStageSelector extends StatefulWidget {
  const GrowthStageSelector({super.key});

  @override
  State<GrowthStageSelector> createState() => _GrowthStageSelectorState();
}

class _GrowthStageSelectorState extends State<GrowthStageSelector> {
  final InmApiService _apiService = InmApiService();
  
  String? _selectedStage;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Available growth stages
  static const List<String> _growthStages = [
    'Vegetative',
    'Flowering',
    'Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentStage();
  }

  Future<void> _loadCurrentStage() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stage = await _apiService.fetchGrowthStage();
      if (mounted) {
        setState(() {
          // Capitalize first letter for display
          _selectedStage = _capitalizeStage(stage);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedStage = 'Vegetative'; // Default
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveStage() async {
    if (_selectedStage == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Convert to lowercase for backend
      final stageToSend = _selectedStage!.toLowerCase();
      final success = await _apiService.saveGrowthStage(stageToSend);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        if (success) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Growth stage updated successfully',
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
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to update growth stage',
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
          _isSaving = false;
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
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
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
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.eco,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Current Growth Stage',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Loading or Dropdown
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Column(
                children: [
                  // Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedStage,
                        items: _growthStages.map((stage) {
                          return DropdownMenuItem(
                            value: stage,
                            child: Row(
                              children: [
                                Icon(
                                  _getStageIcon(stage),
                                  size: 20,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  stage,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedStage = value;
                            });
                          }
                        },
                        icon: const Icon(Icons.arrow_drop_down),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveStage,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Stage'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 12),
            
            // Info text
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All future recommendations will adapt to this stage',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStageIcon(String stage) {
    switch (stage) {
      case 'Vegetative':
        return Icons.spa;
      case 'Flowering':
        return Icons.local_florist;
      case 'Maintenance':
        return Icons.build;
      default:
        return Icons.eco;
    }
  }

  /// Capitalize the first letter of the stage for display
  String _capitalizeStage(String stage) {
    if (stage.isEmpty) return stage;
    return stage[0].toUpperCase() + stage.substring(1).toLowerCase();
  }
}

