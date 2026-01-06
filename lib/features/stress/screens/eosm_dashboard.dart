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
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Consumer<SensorProvider>(
      builder: (BuildContext context, SensorProvider provider, Widget? _) {
        final SensorReading? latest = provider.latestForSelected;
        final EosmStressPrediction? prediction = provider.latestPrediction;
        final List<SensorReading> history = provider.readingsForSelected;
        final List<String> greenhouseOptions = <String>[
          'ALL',
          ...provider.availableGreenhouseIds,
        ];
        final Map<String, String?> ghStations = provider.greenhouseBaseStations;
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
            actions: [
              _buildGreenhouseSelector(
                context: context,
                options: greenhouseOptions,
                selected: selectedGh,
                stations: ghStations,
                onSelect: provider.setSelectedGreenhouse,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.refresh(force: true),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                final double padding = isMobile ? 16.0 : 24.0;
                return ListView(
                  padding: EdgeInsets.all(padding),
                  children: <Widget>[
                    if (prediction != null) ...[
                      _ModernPredictionCard(
                        prediction: prediction,
                        isMobile: isMobile,
                        lastUpdated: latest?.displayTime,
                      ),
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
                    Text(
                      'Trends',
                      style: (isMobile ? textTheme.titleMedium : textTheme.titleLarge)?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    if (history.length >= 2)
                      _TrendGrid(readings: history, isMobile: isMobile)
                    else
                      _EmptyState(
                        message: 'Not enough history yet. Ingest more readings.',
                        onRetry: () => provider.refresh(force: true),
                      ),
                    SizedBox(height: isMobile ? 12 : 16),
                    isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Text(
                                'History',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () => _showHistoryDialog(context, provider),
                                icon: const Icon(Icons.list_alt, size: 18),
                                label: const Text('View full history'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'History',
                                style: textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => _showHistoryDialog(context, provider),
                                icon: const Icon(Icons.list_alt, size: 18),
                                label: const Text('View full history'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
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

void _showHistoryDialog(BuildContext context, SensorProvider provider) {
  showDialog<void>(
    context: context,
    builder: (BuildContext context) => _HistoryDialogContent(provider: provider),
  );
}

class _HistoryDialogContent extends StatefulWidget {
  const _HistoryDialogContent({required this.provider});

  final SensorProvider provider;

  @override
  State<_HistoryDialogContent> createState() => _HistoryDialogContentState();
}

enum _SortColumn {
  time,
  greenhouse,
  basestation,
  temperature,
  humidity,
  soilVoltage,
  uvVoltage,
  gasVoltage,
}

class _HistoryDialogContentState extends State<_HistoryDialogContent> {
  late final ScrollController verticalController;
  late final ScrollController horizontalController;
  
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
  
  // Sorting state
  _SortColumn? _sortColumn;
  bool _sortAscending = true;
  
  @override
  void initState() {
    super.initState();
    verticalController = ScrollController();
    horizontalController = ScrollController();
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
    horizontalController.dispose();
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
      limit: 2000, // Fetch all matching records for sorting/pagination (backend max limit)
    );
    if (mounted) {
      setState(() {
        allRows = fetched;
        if (resetPagination) {
          _displayedCount = _pageSize;
        }
        _applySortAndPagination();
        isLoadingHistory = false;
        _initialLoadDone = true;
      });
    }
  }
  
  void _applySortAndPagination() {
    List<SensorReading> sorted = List<SensorReading>.from(allRows);
    
    // Apply sorting
    if (_sortColumn != null) {
      sorted.sort((a, b) {
        int comparison = 0;
        switch (_sortColumn!) {
          case _SortColumn.time:
            comparison = a.displayTime.compareTo(b.displayTime);
            break;
          case _SortColumn.greenhouse:
            comparison = (a.greenhouseId ?? '').compareTo(b.greenhouseId ?? '');
            break;
          case _SortColumn.basestation:
            comparison = a.basestationId.compareTo(b.basestationId);
            break;
          case _SortColumn.temperature:
            comparison = a.temperature.compareTo(b.temperature);
            break;
          case _SortColumn.humidity:
            comparison = a.humidity.compareTo(b.humidity);
            break;
          case _SortColumn.soilVoltage:
            final double aVal = a.soilVoltage ?? 0;
            final double bVal = b.soilVoltage ?? 0;
            comparison = aVal.compareTo(bVal);
            break;
          case _SortColumn.uvVoltage:
            final double aVal = a.uvVoltage ?? 0;
            final double bVal = b.uvVoltage ?? 0;
            comparison = aVal.compareTo(bVal);
            break;
          case _SortColumn.gasVoltage:
            final double aVal = a.mqVoltage ?? 0;
            final double bVal = b.mqVoltage ?? 0;
            comparison = aVal.compareTo(bVal);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }
    
    // Apply pagination
    displayedRows = sorted.take(_displayedCount).toList();
  }
  
  void _onSort(_SortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _applySortAndPagination();
    });
  }
  
  void _loadMore() {
    setState(() {
      _displayedCount += _pageSize;
      _applySortAndPagination();
    });
  }
  
  DataColumn _buildSortableColumn(String label, _SortColumn column) {
    final bool isSorted = _sortColumn == column;
    return DataColumn(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          if (isSorted)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
            )
          else
            const Icon(Icons.unfold_more, size: 16, color: Colors.grey),
        ],
      ),
      onSort: (int columnIndex, bool ascending) => _onSort(column),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final List<String> ghOptions = <String>[
      'ALL',
      ...widget.provider.availableGreenhouseIds,
    ];
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 1100),
        child: AlertDialog(
          contentPadding: EdgeInsets.all(isMobile ? 12 : 16),
          insetPadding: isMobile
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 0 : 12),
          ),
          content: SizedBox(
            width: isMobile ? MediaQuery.of(context).size.width : MediaQuery.of(context).size.width * 0.9,
            height: isMobile ? MediaQuery.of(context).size.height * 0.9 : MediaQuery.of(context).size.height * 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Full History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: ghOptions.contains(selectedGh) ? selectedGh : 'ALL',
                            items: ghOptions
                                .map(
                                  (String gh) => DropdownMenuItem<String>(
                                    value: gh,
                                    child: Text(gh == 'ALL' ? 'All Greenhouses' : gh),
                                  ),
                                )
                                .toList(),
                            onChanged: (String? value) {
                              setState(() {
                                selectedGh = value ?? 'ALL';
                              });
                              loadHistory(resetPagination: true);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Greenhouse',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setState(() {
                                  startDate = DateTime(picked.year, picked.month, picked.day);
                                });
                                loadHistory(resetPagination: true);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM d, yyyy').format(startDate),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: endDate.subtract(const Duration(days: 1)),
                                firstDate: startDate,
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (picked != null) {
                                setState(() {
                                  endDate = DateTime(picked.year, picked.month, picked.day)
                                      .add(const Duration(days: 1));
                                });
                                loadHistory(resetPagination: true);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM d, yyyy').format(endDate.subtract(const Duration(days: 1))),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: isLoadingHistory ? null : () => loadHistory(resetPagination: true),
                              icon: isLoadingHistory
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.search),
                              label: const Text('Load'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text(
                                'Full History',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(
                                width: 240,
                                child: DropdownButtonFormField<String>(
                                  value: ghOptions.contains(selectedGh) ? selectedGh : 'ALL',
                                  items: ghOptions
                                      .map(
                                        (String gh) => DropdownMenuItem<String>(
                                          value: gh,
                                          child: Text(gh == 'ALL' ? 'All Greenhouses' : gh),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (String? value) {
                                    setState(() {
                                      selectedGh = value ?? 'ALL';
                                    });
                                    loadHistory(resetPagination: true);
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Greenhouse',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: startDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 1)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        startDate = DateTime(picked.year, picked.month, picked.day);
                                      });
                                      loadHistory(resetPagination: true);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      DateFormat('MMM d, yyyy').format(startDate),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final DateTime? picked = await showDatePicker(
                                      context: context,
                                      initialDate: endDate.subtract(const Duration(days: 1)),
                                      firstDate: startDate,
                                      lastDate: DateTime.now().add(const Duration(days: 1)),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        endDate = DateTime(picked.year, picked.month, picked.day)
                                            .add(const Duration(days: 1));
                                      });
                                      loadHistory(resetPagination: true);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'End Date',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      suffixIcon: Icon(Icons.calendar_today),
                                    ),
                                    child: Text(
                                      DateFormat('MMM d, yyyy').format(endDate.subtract(const Duration(days: 1))),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: isLoadingHistory ? null : () => loadHistory(resetPagination: true),
                                icon: isLoadingHistory
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.search),
                                label: const Text('Load'),
                              ),
                            ],
                          ),
                        ],
                      ),
                SizedBox(height: isMobile ? 8 : 12),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isLoadingHistory && !_initialLoadDone
                        ? const Center(child: CircularProgressIndicator())
                        : allRows.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Icon(Icons.inbox, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No data found for selected date range',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: <Widget>[
                                  Expanded(
                                    child: Scrollbar(
                                      controller: verticalController,
                                      thumbVisibility: true,
                                      child: SingleChildScrollView(
                                        controller: verticalController,
                                        primary: false,
                                        child: Scrollbar(
                                          controller: horizontalController,
                                          thumbVisibility: true,
                                          notificationPredicate: (ScrollNotification notification) =>
                                              notification.depth == 1,
                                          child: SingleChildScrollView(
                                            controller: horizontalController,
                                            primary: false,
                                            scrollDirection: Axis.horizontal,
                                            child: DataTable(
                                              columns: <DataColumn>[
                                                _buildSortableColumn('Time', _SortColumn.time),
                                                _buildSortableColumn('Greenhouse', _SortColumn.greenhouse),
                                                _buildSortableColumn('Basestation', _SortColumn.basestation),
                                                _buildSortableColumn('Temp °C', _SortColumn.temperature),
                                                _buildSortableColumn('Hum %', _SortColumn.humidity),
                                                _buildSortableColumn('Soil V', _SortColumn.soilVoltage),
                                                _buildSortableColumn('UV V', _SortColumn.uvVoltage),
                                                _buildSortableColumn('Gas V', _SortColumn.gasVoltage),
                                              ],
                                              rows: displayedRows
                                                  .map(
                                                    (SensorReading r) => DataRow(
                                                      cells: <DataCell>[
                                                        DataCell(Text(
                                                            DateFormat('MMM d HH:mm:ss').format(r.displayTime))),
                                                        DataCell(Text(r.greenhouseId ?? '—')),
                                                        DataCell(Text(r.basestationId)),
                                                        DataCell(Text(r.temperature.toStringAsFixed(1))),
                                                        DataCell(Text(r.humidity.toStringAsFixed(1))),
                                                        DataCell(Text(r.soilVoltage?.toStringAsFixed(2) ?? '—')),
                                                        DataCell(Text(r.uvVoltage?.toStringAsFixed(2) ?? '—')),
                                                        DataCell(Text(r.mqVoltage?.toStringAsFixed(2) ?? '—')),
                                                      ],
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_displayedCount < allRows.length)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: OutlinedButton.icon(
                                        onPressed: _loadMore,
                                        icon: const Icon(Icons.expand_more),
                                        label: Text(
                                          'Load More (${allRows.length - _displayedCount} remaining)',
                                        ),
                                      ),
                                    ),
                                  if (_displayedCount >= allRows.length && allRows.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Showing all ${allRows.length} records',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
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

Widget _buildGreenhouseSelector({
  required BuildContext context,
  required List<String> options,
  required String selected,
  required Map<String, String?> stations,
  required ValueChanged<String?> onSelect,
}) {
  return PopupMenuButton<String>(
    initialValue: selected,
    onSelected: onSelect,
    icon: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.agriculture, size: 16, color: Color(0xFF4CAF50)),
          const SizedBox(width: 6),
          Text(
            selected == 'ALL' ? 'All' : selected,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF4CAF50)),
        ],
      ),
    ),
    tooltip: 'Select Greenhouse',
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    itemBuilder: (BuildContext context) => options.map((String id) {
      return PopupMenuItem<String>(
        value: id,
        child: Row(
          children: [
            Icon(
              id == 'ALL' ? Icons.grid_view : Icons.agriculture,
              size: 18,
              color: selected == id ? const Color(0xFF4CAF50) : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                id == 'ALL' ? 'All Greenhouses' : id,
                style: TextStyle(
                  fontWeight: selected == id ? FontWeight.bold : FontWeight.normal,
                  color: selected == id ? const Color(0xFF1B5E20) : null,
                ),
              ),
            ),
            if (stations[id] != null) ...[
              const SizedBox(width: 8),
              Text(
                stations[id]!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      );
    }).toList(),
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
                  GaugeSegment(to: 40, color: const Color(0xFFFF6B35)),
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
                  GaugeSegment(to: 100, color: const Color(0xFF2196F3)),
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
        color = const Color(0xFFFF6B35);
        points = _map(widget.readings, (SensorReading r) => r.temperature);
        break;
      case _MetricType.humidity:
        title = 'Humidity (%)';
        unit = '%';
        color = const Color(0xFF2196F3);
        points = _map(widget.readings, (SensorReading r) => r.humidity);
        break;
      case _MetricType.soilVoltage:
        title = 'Soil Voltage (V)';
        unit = 'V';
        color = const Color(0xFF8B4513);
        points = _map(widget.readings, (SensorReading r) => r.soilVoltage);
        break;
      case _MetricType.gasVoltage:
        title = 'Gas Voltage (V)';
        unit = 'V';
        color = const Color(0xFF9C27B0);
        points = _map(widget.readings, (SensorReading r) => r.mqVoltage);
        break;
      case _MetricType.uvVoltage:
        title = 'UV Voltage (V)';
        unit = 'V';
        color = const Color(0xFFFFC107);
        points = _map(widget.readings, (SensorReading r) => r.uvVoltage);
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_MetricType>(
            segments: const <ButtonSegment<_MetricType>>[
              ButtonSegment<_MetricType>(
                value: _MetricType.temperature,
                label: Text('Temp'),
                icon: Icon(Icons.thermostat, size: 16),
              ),
              ButtonSegment<_MetricType>(
                value: _MetricType.humidity,
                label: Text('Hum'),
                icon: Icon(Icons.water_drop, size: 16),
              ),
              ButtonSegment<_MetricType>(
                value: _MetricType.soilVoltage,
                label: Text('Soil'),
                icon: Icon(Icons.grass, size: 16),
              ),
              ButtonSegment<_MetricType>(
                value: _MetricType.gasVoltage,
                label: Text('Gas'),
                icon: Icon(Icons.air, size: 16),
              ),
              ButtonSegment<_MetricType>(
                value: _MetricType.uvVoltage,
                label: Text('UV'),
                icon: Icon(Icons.wb_sunny, size: 16),
              ),
            ],
            selected: <_MetricType>{_selectedMetric},
            onSelectionChanged: (Set<_MetricType> newSelection) {
              setState(() {
                _selectedMetric = newSelection.first;
              });
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white,
              selectedBackgroundColor: color.withOpacity(0.1),
              selectedForegroundColor: color,
              side: BorderSide(color: Colors.grey.shade300),
            ),
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
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isMobile ? 12 : 16),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: stressColor.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.psychology, color: stressColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Stress:',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                prediction.stressLabel,
                style: TextStyle(
                  fontSize: isMobile ? 22 : 26,
                  fontWeight: FontWeight.w900,
                  color: stressColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: stressColor.withOpacity(0.2)),
                ),
                child: Text(
                  '${(prediction.highestProbability * 100).toStringAsFixed(0)}% Confidence',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: stressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.lightbulb_outline, color: stressColor, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    recommendation,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Moved time and date here
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.schedule,
                size: 12,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Text(
                'Updated: $formatted',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Responsive grid: 2 columns on mobile, 3-6 on desktop
        final int columns = isMobile
            ? 2
            : constraints.maxWidth > 1200
                ? 6
                : constraints.maxWidth > 900
                    ? 4
                    : 3;
        final double spacing = isMobile ? 12 : 16;
        final double cardWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        
        final List<_MetricItem> metrics = <_MetricItem>[
          _MetricItem(
            title: 'Temperature',
            value: '${latest.temperature.toStringAsFixed(1)}°C',
            icon: Icons.thermostat,
            color: const Color(0xFFFF6B35), // Vibrant orange
            bgColor: const Color(0xFFFFF3E0),
          ),
          _MetricItem(
            title: 'Humidity',
            value: '${latest.humidity.toStringAsFixed(1)}%',
            icon: Icons.water_drop,
            color: const Color(0xFF2196F3), // Bright blue
            bgColor: const Color(0xFFE3F2FD),
          ),
          _MetricItem(
            title: 'Soil Moisture',
            value: latest.soilVoltage != null
                ? '${latest.soilVoltage!.toStringAsFixed(2)}V'
                : '—',
            icon: Icons.grass,
            color: const Color(0xFF8B4513), // Brown
            bgColor: const Color(0xFFEFEBE9),
          ),
          _MetricItem(
            title: 'UV Sensor',
            value: latest.uvVoltage != null
                ? '${latest.uvVoltage!.toStringAsFixed(2)}V'
                : '—',
            icon: Icons.wb_sunny,
            color: const Color(0xFFFFC107), // Amber
            bgColor: const Color(0xFFFFF9C4),
          ),
          _MetricItem(
            title: 'Gas Sensor',
            value: latest.mqVoltage != null
                ? '${latest.mqVoltage!.toStringAsFixed(2)}V'
                : '—',
            icon: Icons.air,
            color: const Color(0xFF9C27B0), // Purple
            bgColor: const Color(0xFFF3E5F5),
          ),
          if (latest.greenhouseId != null)
            _MetricItem(
              title: 'Greenhouse',
              value: latest.greenhouseId!,
              icon: Icons.local_florist,
              color: const Color(0xFF4CAF50), // Green
              bgColor: const Color(0xFFE8F5E9),
            ),
        ];

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      metric.bgColor,
                      metric.bgColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
                ),
                child: Icon(
                  metric.icon,
                  color: metric.color,
                  size: isMobile ? 26 : 32,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 18),
          Text(
            metric.title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: metric.color,
              letterSpacing: 0.5,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
// End of EOSM


