import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/sensor_reading.dart';
import '../../../shared/models/eosm_stress_prediction.dart';
import '../../../shared/providers/sensor_provider.dart';
import '../../../shared/widgets/stress_gauge.dart';
import '../../../shared/widgets/trend_chart.dart';
import '../../../shared/widgets/gradient_header.dart';

class EosmDashboardScreen extends StatefulWidget {
  const EosmDashboardScreen({super.key});

  @override
  State<EosmDashboardScreen> createState() => _EosmDashboardScreenState();
}

class _EosmDashboardScreenState extends State<EosmDashboardScreen> {
  late final SensorProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = SensorProvider();
    // Kick off initial and periodic refresh.
    unawaited(_provider.startAutoRefresh());
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SensorProvider>.value(
      value: _provider,
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return Consumer<SensorProvider>(
      builder: (BuildContext context, SensorProvider provider, Widget? _) {
        final SensorReading? latest = provider.latestForSelected;
        final EosmStressPrediction? prediction = provider.latestPrediction;
        final List<SensorReading> history = provider.readingsForSelected;
        final List<String> greenhouseOptions = <String>[
          'ALL',
          ...provider.availableGreenhouseIds,
        ];
        final String selectedGh = provider.selectedGreenhouseId ?? 'ALL';

        if (provider.isLoading && latest == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
                      appBar: GradientHeader.buildAppBar(
                        context: context,
                        title: 'Stress Monitoring',
                        onBackPressed: () => Navigator.of(context).pop(),
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(force: true),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                final double padding = isMobile ? 16.0 : 24.0;
                return ListView(
                              padding: EdgeInsets.fromLTRB(padding, 8, padding, padding),
                  children: <Widget>[
                                _buildGreenhouseFilterBar(
                                  options: greenhouseOptions,
                                  selected: selectedGh,
                      onSelect: provider.setSelectedGreenhouse,
                      isMobile: isMobile,
                    ),
                                const SizedBox(height: 16),
                                if (prediction != null) ...[
                                  _ModernPredictionCard(
                                    prediction: prediction,
                                    isMobile: isMobile,
                                    lastUpdated: latest?.displayTime,
                                  ),
                                  const SizedBox(height: 16),
                                  _ModernEnergyOptimizationCard(isMobile: isMobile),
                    SizedBox(height: isMobile ? 16 : 24),
                                ],
                    if (provider.errorMessage != null && latest == null)
                      _ErrorBanner(message: provider.errorMessage!),
                    if (latest != null) ...<Widget>[
                      _MetricsGrid(latest: latest, isMobile: isMobile),
                      SizedBox(height: isMobile ? 16 : 24),
                      _GaugeRow(latest: latest, isMobile: isMobile),
                      SizedBox(height: isMobile ? 16 : 24),
                    ] else
                      _EmptyState(
                        message: 'No readings for this selection.',
                        onRetry: () => provider.refresh(force: true),
                      ),
                                _buildSectionHeader(context, 'Trends', isMobile),
                    SizedBox(height: isMobile ? 8 : 12),
                    if (history.length >= 2)
                      _TrendGrid(readings: history, isMobile: isMobile)
                    else
                      _EmptyState(
                        message: 'Not enough history yet. Ingest more readings.',
                        onRetry: () => provider.refresh(force: true),
                      ),
                                SizedBox(height: isMobile ? 24 : 32),
                                _buildSectionHeader(
                                  context, 
                                'History',
                                  isMobile,
                                  trailing: GestureDetector(
                                    onTap: () => _showHistoryDialog(context, provider),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF4CAF50).withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'See All',
                                            style: TextStyle(
                                              color: const Color(0xFF1B5E20),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                                          const SizedBox(width: 2),
                                          const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 14,
                                            color: Color(0xFF1B5E20),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _RecentActivityLog(
                                  readings: history.take(5).toList(),
                                  isMobile: isMobile,
                                ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _RecentActivityLog extends StatelessWidget {
  const _RecentActivityLog({required this.readings, required this.isMobile});

  final List<SensorReading> readings;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: readings.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Colors.grey.shade100,
        ),
        itemBuilder: (context, index) {
          final reading = readings[index];
          return _ActivityLogItem(reading: reading, isMobile: isMobile);
        },
      ),
    );
  }
}

class _ModernEnergyOptimizationCard extends StatefulWidget {
  const _ModernEnergyOptimizationCard({required this.isMobile});
  final bool isMobile;

  @override
  State<_ModernEnergyOptimizationCard> createState() => _ModernEnergyOptimizationCardState();
}

class _ModernEnergyOptimizationCardState extends State<_ModernEnergyOptimizationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Quick Impact Stats (Always visible)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFF1B5E20), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Energy Optimization',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                            Text(
                              'AI-recommended actuator control',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Pill showing total saving
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '≈38% SAVING',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Expansion Arrow
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade400,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2, 3, 4 Sections (Visible only when expanded)
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // 2. Main Impact Progress Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9), // Very light fresh green
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA5D6A7).withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ESTIMATED ENERGY USAGE',
                            style: TextStyle(
                              color: const Color(0xFF1B5E20).withOpacity(0.6),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const Text(
                            '2.8 kWh',
                            style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: 0.38,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                                ),
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Actuator Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardWidth = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(width: cardWidth, child: _buildActuatorChip('Fan Level', 'HIGH', Icons.mode_fan_off_rounded, const Color(0xFFF44336))),
                        SizedBox(width: cardWidth, child: _buildActuatorChip('Water Pump', 'LOW', Icons.water_rounded, const Color(0xFFA5D6A7))),
                        SizedBox(width: cardWidth, child: _buildActuatorChip('AC Level', 'MEDIUM', Icons.ac_unit_rounded, const Color(0xFFFFCC80))),
                        SizedBox(width: cardWidth, child: _buildActuatorChip('UV Shade', 'FULL', Icons.wb_shade_rounded, const Color(0xFFF44336))),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // 4. ML Reasoning
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: const Color(0xFF1B5E20), width: 4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.psychology_rounded, color: Color(0xFF1B5E20), size: 20),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI REASONING',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B5E20),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Extreme Humidity (91.2%) detected. To prevent fungal stress, the AI has Reduced Water and prioritized Max Fans for air circulation. AC is set to MEDIUM for essential dehumidification, while FULL SHADING blocks solar heat, maintaining safety with 35% efficiency.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildActuatorChip(String title, String level, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 15,
                    color: color,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

            class _ActivityLogItem extends StatelessWidget {
              const _ActivityLogItem({required this.reading, required this.isMobile});

              final SensorReading reading;
              final bool isMobile;

              @override
              Widget build(BuildContext context) {
                final timeStr = DateFormat('HH:mm:ss').format(reading.displayTime);
                final dateStr = DateFormat('MMM d').format(reading.displayTime);
                
                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      // Date & Time
                      SizedBox(
                        width: isMobile ? 75 : 85,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey.shade400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                      ),
                      const SizedBox(width: 8),
                      // Data Row
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _buildMiniMetric(Icons.thermostat, '${reading.temperature.toStringAsFixed(1)}°', const Color(0xFFFFCC80)),
                              const SizedBox(width: 12),
                              _buildMiniMetric(Icons.water_drop, '${reading.humidity.toStringAsFixed(0)}%', const Color(0xFF90CAF9)),
                              const SizedBox(width: 12),
                              if (reading.soilVoltage != null) ...[
                                _buildMiniMetric(Icons.grass, '${reading.soilVoltage!.toStringAsFixed(1)}V', const Color(0xFFBCAAA4)),
                                const SizedBox(width: 12),
                              ],
                              if (reading.uvVoltage != null) ...[
                                _buildMiniMetric(Icons.wb_sunny, '${reading.uvVoltage!.toStringAsFixed(1)}V', const Color(0xFFFFE082)),
                                const SizedBox(width: 12),
                              ],
                              if (reading.mqVoltage != null)
                                _buildMiniMetric(Icons.air, '${reading.mqVoltage!.toStringAsFixed(1)}V', const Color(0xFFF48FB1)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFA5D6A7),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
          ),
        );
              }

              Widget _buildMiniMetric(IconData icon, String value, Color color) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
    );
  }
}

void _showHistoryDialog(BuildContext context, SensorProvider provider) {
  final bool isMobile = MediaQuery.of(context).size.width < 600;
  
  if (isMobile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _HistoryDialogContent(provider: provider),
      ),
    );
  } else {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => _HistoryDialogContent(provider: provider),
  );
  }
}

class _HistoryDialogContent extends StatefulWidget {
  const _HistoryDialogContent({required this.provider});

  final SensorProvider provider;

  @override
  State<_HistoryDialogContent> createState() => _HistoryDialogContentState();
}

class _HistoryDialogContentState extends State<_HistoryDialogContent> {
  late final ScrollController verticalController;
  
  // Initialize with current date
  late DateTime startDate;
  late DateTime endDate;
  List<SensorReading> allRows = <SensorReading>[]; // All fetched rows
  List<SensorReading> displayedRows = <SensorReading>[]; // Currently displayed rows
  bool isLoadingHistory = false;
  String selectedGh = 'ALL';
  bool _initialLoadDone = false;
  int _displayedCount = 20; // Initial display count
  static const int _pageSize = 20;
  
  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    // Use local date for today (user's timezone)
    final DateTime now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    startDate = todayStart;
    endDate = todayStart.add(const Duration(days: 1));
    selectedGh = widget.provider.selectedGreenhouseId ?? 'ALL';
    
    // Load initial data for today
    WidgetsBinding.instance.addPostFrameCallback((_) => loadHistory());
  }
  
  @override
  void dispose() {
    verticalController.dispose();
    super.dispose();
  }
  
  Future<void> loadHistory({bool resetPagination = true}) async {
    setState(() {
      isLoadingHistory = true;
    });
    final List<SensorReading> fetched = await widget.provider.fetchHistoryForDateRange(
      startDate: startDate,
      endDate: endDate,
      greenhouseId: selectedGh == 'ALL' ? null : selectedGh,
      limit: 2000,
    );
    if (mounted) {
      setState(() {
        allRows = fetched;
        if (resetPagination) {
          _displayedCount = _pageSize;
        }
        displayedRows = allRows.take(_displayedCount).toList();
        isLoadingHistory = false;
        _initialLoadDone = true;
      });
    }
  }
  
  void _loadMore() {
    setState(() {
      _displayedCount += _pageSize;
      displayedRows = allRows.take(_displayedCount).toList();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final List<String> ghOptions = <String>[
      'ALL',
      ...widget.provider.availableGreenhouseIds,
    ];
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final theme = Theme.of(context);
    
    // Main Content of the History (extracted to reuse)
    Widget buildContent() {
      return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
          // Filters Bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
            child: Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Greenhouse Selector
                  _buildGreenhouseFilterBar(
                    options: ghOptions,
                    selected: selectedGh,
                    onSelect: (val) {
                      setState(() => selectedGh = val ?? 'ALL');
                      loadHistory();
                            },
                    isMobile: isMobile,
                          ),
                  const SizedBox(height: 16),
                  // Date Selectors
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePicker(
                          label: 'From',
                          date: startDate,
                            onTap: () async {
                            final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                              setState(() => startDate = picked);
                              loadHistory();
                              }
                            },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDatePicker(
                          label: 'To',
                          date: endDate.subtract(const Duration(days: 1)),
                            onTap: () async {
                            final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate.subtract(const Duration(days: 1)),
                                firstDate: startDate,
                              lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                              setState(() => endDate = picked.add(const Duration(days: 1)));
                              loadHistory();
                              }
                            },
                        ),
                      ),
                    ],
                  ),
                ],
                              ),
                            ),
                          ),
          const SizedBox(height: 20),
          
          // Results List
          Expanded(
            child: isLoadingHistory && !_initialLoadDone
                ? const Center(child: CircularProgressIndicator())
                : allRows.isEmpty
                    ? _buildEmptyState('No records found for this period.')
                    : ListView.separated(
                        controller: verticalController,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 8),
                        itemCount: displayedRows.length + (displayedRows.length < allRows.length ? 1 : 0),
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == displayedRows.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: OutlinedButton(
                                onPressed: _loadMore,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text('Load More (${allRows.length - displayedRows.length} left)'),
                              ),
                            );
                          }
                          return _DetailedHistoryCard(reading: displayedRows[index], isMobile: isMobile);
                        },
                                ),
                              ),
                            ],
      );
    }

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: GradientHeader.buildAppBar(
                                      context: context,
          title: 'Full Activity Log',
          onBackPressed: () => Navigator.of(context).pop(),
        ),
        body: buildContent(),
                                    );
    }

    return Dialog(
      backgroundColor: const Color(0xFFF5F5F5),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header (Desktop only as AppBar handles it on Mobile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Full Activity Log',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.black87),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                ],
                                ),
                              ),
            const SizedBox(height: 20),
            Expanded(child: buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({required String label, required DateTime date, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
                                child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                                    Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                              ),
                            ],
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DetailedHistoryCard extends StatelessWidget {
  const _DetailedHistoryCard({required this.reading, required this.isMobile});
  final SensorReading reading;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(reading.displayTime);
    final timeStr = DateFormat('h:mm:ss a').format(reading.displayTime);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr, 
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.black
                    )
                  ),
                  Text(
                    timeStr, 
                    style: TextStyle(
                      fontSize: isMobile ? 10 : 11, 
                      color: Colors.grey.shade500, 
                      fontWeight: FontWeight.w600
                    )
                  ),
                ],
              ),
              if (reading.greenhouseId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    reading.greenhouseId!,
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 11, 
                      fontWeight: FontWeight.w800, 
                      color: const Color(0xFF1B5E20)
                                      ),
                                    ),
                                  ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildMetricItem(Icons.thermostat, '${reading.temperature.toStringAsFixed(1)}°', 'Temp', const Color(0xFFFFCC80)),
                const SizedBox(width: 16),
                _buildMetricItem(Icons.water_drop, '${reading.humidity.toStringAsFixed(0)}%', 'Hum', const Color(0xFF90CAF9)),
                const SizedBox(width: 16),
                if (reading.soilVoltage != null) ...[
                  _buildMetricItem(Icons.grass, '${reading.soilVoltage!.toStringAsFixed(1)}V', 'Soil', const Color(0xFFBCAAA4)),
                  const SizedBox(width: 16),
                ],
                if (reading.uvVoltage != null) ...[
                  _buildMetricItem(Icons.wb_sunny, '${reading.uvVoltage!.toStringAsFixed(1)}V', 'UV', const Color(0xFFFFE082)),
                  const SizedBox(width: 16),
                ],
                if (reading.mqVoltage != null)
                  _buildMetricItem(Icons.air, '${reading.mqVoltage!.toStringAsFixed(1)}V', 'Gas', const Color(0xFFF48FB1)),
              ],
                                        ),
                                      ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value, 
              style: const TextStyle(
                fontSize: 13, 
                fontWeight: FontWeight.bold, 
                color: Colors.black87
              )
            ),
            Text(
              label, 
              style: TextStyle(
                fontSize: 8, 
                color: Colors.grey.shade500, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 0.5
              )
                                    ),
                                ],
                              ),
      ],
    );
  }
}

Widget _buildSectionHeader(BuildContext context, String title, bool isMobile, {Widget? trailing}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: isMobile ? 18 : 22,
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20), // deepForestGreen
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
            ),
          ],
        ),
      if (trailing != null) trailing,
    ],
    );
}

String _formatDateTime(DateTime dt, {bool isMobile = false}) {
  // Backend sends IST time directly, so we just format it
  // Format date/time manually to ensure colons are always used for time separator
  final String dayName = DateFormat('EEE', 'en_US').format(dt);
  final String month = DateFormat('MMM', 'en_US').format(dt);
  final String day = dt.day.toString();
  final String year = dt.year.toString();
  final String hour = dt.hour.toString().padLeft(2, '0');
  final String minute = dt.minute.toString().padLeft(2, '0');
  
  if (isMobile) {
    return '$dayName, $day $month • $hour:$minute';
  } else {
    return '$dayName, $day $month $year • $hour:$minute';
  }
}

Widget _buildGreenhouseFilterBar({
  required List<String> options,
  required String selected,
  required ValueChanged<String?> onSelect,
  required bool isMobile,
}) {
  return SizedBox(
    height: 44, // Slightly taller for better touch targets
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4), // Small internal padding
      itemCount: options.length,
      physics: const BouncingScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final String id = options[index];
        final bool isSelected = selected == id;
        
        return ChoiceChip(
          label: Text(
            id == 'ALL' ? 'All Greenhouses' : id,
            style: TextStyle(
              color: isSelected ? const Color(0xFF1B5E20) : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
                  ),
            ),
          selected: isSelected,
          onSelected: (bool selected) {
            if (selected) onSelect(id);
          },
          selectedColor: const Color(0xFF4CAF50).withOpacity(0.15),
          backgroundColor: Colors.white,
          checkmarkColor: const Color(0xFF1B5E20),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
    );
      },
    ),
  );
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({required this.latest, required this.isMobile});

  final SensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = !isMobile && constraints.maxWidth > 900;
        final double width = wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: isMobile ? 12 : 16,
          runSpacing: isMobile ? 12 : 16,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.start,
          children: <Widget>[
            SizedBox(
              width: width,
              child: StressGauge(
                title: 'Temperature',
                value: latest.temperature,
                unit: '°C',
                min: 0,
                max: 40,
                segments: <GaugeSegment>[
                  GaugeSegment(to: 40, color: const Color(0xFFFFCC80)), // Soft Orange (200)
                ],
              ),
            ),
            SizedBox(
              width: width,
              child: StressGauge(
                title: 'Humidity',
                value: latest.humidity,
                unit: '%',
                min: 0,
                max: 100,
                segments: <GaugeSegment>[
                  GaugeSegment(to: 100, color: const Color(0xFF90CAF9)), // Soft Blue (200)
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}


enum _MetricType { temperature, humidity, soilVoltage, gasVoltage, uvVoltage }

class _TrendGrid extends StatefulWidget {
  const _TrendGrid({required this.readings, required this.isMobile});

  final List<SensorReading> readings;
  final bool isMobile;

  @override
  State<_TrendGrid> createState() => _TrendGridState();
}

class _TrendGridState extends State<_TrendGrid> {
  _MetricType _selectedMetric = _MetricType.temperature;

  List<TrendPoint> _map(List<SensorReading> source, double? Function(SensorReading) selector) {
    return source
        .where((SensorReading r) => selector(r) != null)
        .map((SensorReading r) => TrendPoint(r.displayTime, selector(r)!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String unit;
    Color color;
    List<TrendPoint> points;

    switch (_selectedMetric) {
      case _MetricType.temperature:
        title = 'Temperature (°C)';
        unit = '°C';
        color = const Color(0xFFFFCC80); // Soft Orange (200)
        points = _map(widget.readings, (SensorReading r) => r.temperature);
        break;
      case _MetricType.humidity:
        title = 'Humidity (%)';
        unit = '%';
        color = const Color(0xFF90CAF9); // Soft Blue (200)
        points = _map(widget.readings, (SensorReading r) => r.humidity);
        break;
      case _MetricType.soilVoltage:
        title = 'Soil Voltage (V)';
        unit = 'V';
        color = const Color(0xFFBCAAA4); // Soft Brown (200)
        points = _map(widget.readings, (SensorReading r) => r.soilVoltage);
        break;
      case _MetricType.gasVoltage:
        title = 'Gas Voltage (V)';
        unit = 'V';
        color = const Color(0xFFF48FB1); // Soft Rose (200)
        points = _map(widget.readings, (SensorReading r) => r.mqVoltage);
        break;
      case _MetricType.uvVoltage:
        title = 'UV Voltage (V)';
        unit = 'V';
        color = const Color(0xFFFFE082); // Soft Yellow/Amber (200)
        points = _map(widget.readings, (SensorReading r) => r.uvVoltage);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            children: <Widget>[
              _buildMetricTab(_MetricType.temperature, 'Temp', Icons.thermostat, const Color(0xFFFFCC80)),
              _buildMetricTab(_MetricType.humidity, 'Hum', Icons.water_drop, const Color(0xFF90CAF9)),
              _buildMetricTab(_MetricType.soilVoltage, 'Soil', Icons.grass, const Color(0xFFBCAAA4)),
              _buildMetricTab(_MetricType.gasVoltage, 'Gas', Icons.air, const Color(0xFFF48FB1)),
              _buildMetricTab(_MetricType.uvVoltage, 'UV', Icons.wb_sunny, const Color(0xFFFFE082)),
            ],
              ),
            ),
        const SizedBox(height: 16),
        TrendChart(
          title: title,
          unit: unit,
          color: color,
                optimalMin: null,
                optimalMax: null,
          points: points,
        ),
      ],
    );
  }

  Widget _buildMetricTab(_MetricType type, String label, IconData icon, Color color) {
    final bool isSelected = _selectedMetric == type;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => setState(() => _selectedMetric = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : Colors.grey.shade500,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.black : Colors.grey.shade500,
                  letterSpacing: 0.2,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_rounded, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        const SizedBox(height: 12),
        Icon(Icons.sensors_off, size: 42, color: scheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _ModernPredictionCard extends StatelessWidget {
  const _ModernPredictionCard({
    required this.prediction,
    required this.isMobile,
    this.lastUpdated,
  });

  final EosmStressPrediction prediction;
  final bool isMobile;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final Color stressColor = prediction.stressColor;
    final String recommendation = _getRecommendation(prediction.stressLabel);
    final String formatted = lastUpdated != null
        ? _formatDateTime(lastUpdated!, isMobile: isMobile)
        : 'Waiting for first reading';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, stressColor, 0.05),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: stressColor.withOpacity(0.08),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
        ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Top Row: Analysis Label & Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                    Row(
                children: [
              Container(
                    width: 6,
                    height: 6,
                decoration: BoxDecoration(
                      color: stressColor,
                  shape: BoxShape.circle,
                    ),
            ),
                const SizedBox(width: 8),
                  Text(
                    'ML STRESS ANALYSIS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
              Text(
                formatted,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
          const SizedBox(height: 12),
          
          // Middle Row: Status & Confidence
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
              Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  color: stressColor,
                                  size: isMobile ? (MediaQuery.of(context).size.width < 340 ? 32 : 42) : 48,
                    ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                      prediction.stressLabel,
                      style: TextStyle(
                                      fontSize: isMobile ? (MediaQuery.of(context).size.width < 340 ? 28 : 34) : 40,
                                      fontWeight: FontWeight.w900,
                        color: stressColor,
                                      letterSpacing: -1.0,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                    Text(
                      '${(prediction.highestProbability * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                                  fontSize: isMobile ? 20 : 24,
                                  fontWeight: FontWeight.w900,
                        color: stressColor,
                                  height: 1.0,
                      ),
                    ),
                              const SizedBox(height: 2),
                    Text(
                                'CONFIDENCE',
                      style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: stressColor.withOpacity(0.8),
                                  letterSpacing: 0.8,
                      ),
                    ),
                  ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Recommendation Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: stressColor, width: 4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: stressColor,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                          ),
                        ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  String _getRecommendation(String stressLabel) {
    switch (stressLabel.toUpperCase()) {
      case 'HIGH':
        return 'Immediate action required. Check environmental conditions.';
      case 'MEDIUM':
        return 'Monitor closely. Review recent sensor trends.';
      case 'LOW':
        return 'Conditions are optimal. Maintain current settings.';
      default:
        return 'Continue monitoring plant health.';
    }
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.latest, required this.isMobile});

  final SensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
        final List<_MetricItem> metrics = <_MetricItem>[
          _MetricItem(
            title: 'Soil Moisture',
        value: latest.soilVoltage != null ? '${latest.soilVoltage!.toStringAsFixed(2)}V' : '—',
            icon: Icons.grass,
        color: const Color(0xFFBCAAA4), // Soft Brown (200)
        bgColor: const Color(0xFFEFEBE9), // Brown 50
          ),
          _MetricItem(
            title: 'UV Sensor',
        value: latest.uvVoltage != null ? '${latest.uvVoltage!.toStringAsFixed(2)}V' : '—',
            icon: Icons.wb_sunny,
        color: const Color(0xFFFFE082), // Soft Amber (200)
        bgColor: const Color(0xFFFFF8E1), // Amber 50
          ),
          _MetricItem(
            title: 'Gas Sensor',
        value: latest.mqVoltage != null ? '${latest.mqVoltage!.toStringAsFixed(2)}V' : '—',
            icon: Icons.air,
        color: const Color(0xFFF48FB1), // Soft Rose (200)
        bgColor: const Color(0xFFFCE4EC), // Rose 50
          ),
          if (latest.greenhouseId != null)
            _MetricItem(
              title: 'Greenhouse',
              value: latest.greenhouseId!,
              icon: Icons.local_florist,
          color: const Color(0xFFA5D6A7), // Soft Green (200)
          bgColor: const Color(0xFFE8F5E9), // Green 50
            ),
        ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Automatically adjust columns to fill space
        int columns;
        if (isMobile) {
          // Extremely small devices (like small emulators) use 1 column
          columns = constraints.maxWidth < 340 ? 1 : 2;
        } else {
          // On desktop, try to fit all in one row, but max 4
          columns = metrics.length > 4 ? 4 : metrics.length;
          // Ensure we don't have too many columns for small widths
          if (constraints.maxWidth < 600) columns = 2;
          else if (constraints.maxWidth < 900) columns = 3;
        }

        final double spacing = isMobile ? 12 : 16;
        final double cardWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics.map((_MetricItem metric) {
            return SizedBox(
              width: cardWidth,
              child: _ModernMetricCard(metric: metric, isMobile: isMobile),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

class _ModernMetricCard extends StatelessWidget {
  const _ModernMetricCard({required this.metric, required this.isMobile});

  final _MetricItem metric;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          // Visual (Icon) on the left
              Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      metric.bgColor,
                      metric.bgColor.withOpacity(0.7),
                    ],
                  ),
              borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  metric.icon,
                  color: metric.color,
              size: isMobile ? 22 : 26,
                ),
              ),
          const SizedBox(width: 14),
          // Data on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
          Text(
            metric.title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
                const SizedBox(height: 2),
          Text(
            metric.value,
            style: TextStyle(
                    fontSize: isMobile ? (MediaQuery.of(context).size.width < 340 ? 16 : 18) : 22,
              fontWeight: FontWeight.bold,
              color: metric.color,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// End of EOSM


