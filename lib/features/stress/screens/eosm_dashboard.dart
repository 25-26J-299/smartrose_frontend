import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../shared/models/sensor_reading.dart';
import '../../../shared/models/eosm_stress_prediction.dart';
import '../../../shared/providers/sensor_provider.dart';
import '../../../shared/utils/collection_extensions.dart';
import '../../../shared/widgets/stress_gauge.dart';
import '../../../shared/widgets/trend_chart.dart';

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
    final ColorScheme scheme = Theme.of(context).colorScheme;
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
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            title: const Text('Stress Monitoring'),
            centerTitle: false,
            elevation: 0,
            backgroundColor: Colors.transparent,
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
                    _ModernHeader(
                      selectedGreenhouse: selectedGh,
                      lastUpdated: latest?.displayTime,
                      baseStationId: latest?.basestationId,
                      scheme: scheme,
                      greenhouseOptions: greenhouseOptions,
                      greenhouseStations: ghStations,
                      onSelect: provider.setSelectedGreenhouse,
                      isMobile: isMobile,
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                    if (provider.errorMessage != null && latest == null)
                      _ErrorBanner(message: provider.errorMessage!),
                    if (latest != null) ...<Widget>[
                      if (prediction != null) ...<Widget>[
                        _ModernPredictionCard(prediction: prediction, latest: latest, isMobile: isMobile),
                        SizedBox(height: isMobile ? 16 : 24),
                      ],
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

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedGreenhouse,
    required this.lastUpdated,
    required this.baseStationId,
    required this.scheme,
    required this.greenhouseOptions,
    required this.greenhouseStations,
    required this.onSelect,
    required this.isMobile,
  });

  final String selectedGreenhouse;
  final DateTime? lastUpdated;
  final String? baseStationId;
  final ColorScheme scheme;
  final List<String> greenhouseOptions;
  final Map<String, String?> greenhouseStations;
  final ValueChanged<String?> onSelect;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final String formatted = lastUpdated != null
        ? _formatDateTime(lastUpdated!, isMobile: isMobile)
        : 'Waiting for first reading';
    final String titleSuffix =
        selectedGreenhouse == 'ALL' ? 'All Greenhouses' : selectedGreenhouse;
    
    final Widget titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    scheme.primary,
                    scheme.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.local_florist, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SmartRose',
                style: (isMobile
                        ? Theme.of(context).textTheme.titleLarge
                        : Theme.of(context).textTheme.headlineSmall)
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$titleSuffix Dashboard',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        Row(
          children: <Widget>[
            Icon(Icons.schedule, size: isMobile ? 14 : 16, color: scheme.onSurfaceVariant),
            SizedBox(width: isMobile ? 3 : 4),
            Flexible(
              child: Text(
                'Last updated: $formatted',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (baseStationId != null) ...<Widget>[
          SizedBox(height: isMobile ? 4 : 6),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 6 : 8,
              vertical: isMobile ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.sensors, size: isMobile ? 12 : 14),
                SizedBox(width: isMobile ? 3 : 4),
                Flexible(
                  child: Text(
                    'Base Station: $baseStationId',
                    style: TextStyle(fontSize: isMobile ? 11 : null),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final Widget dropdown = SizedBox(
      width: isMobile ? double.infinity : 220,
      child: DropdownButtonFormField<String>(
            initialValue: greenhouseOptions.contains(selectedGreenhouse)
                ? selectedGreenhouse
                : greenhouseOptions.firstOrNull,
            items: greenhouseOptions
                .map(
                  (String id) => DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      id == 'ALL'
                          ? 'All Greenhouses'
                          : '$id${greenhouseStations[id] != null ? ' · ${greenhouseStations[id]}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: onSelect,
            decoration: const InputDecoration(
              labelText: 'Greenhouse',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          titleSection,
          const SizedBox(height: 12),
          dropdown,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: titleSection),
        const SizedBox(width: 16),
        dropdown,
      ],
    );
  }
}

class _GaugeRow extends StatelessWidget {
  const _GaugeRow({required this.latest, required this.isMobile});

  final SensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
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


class _RawPanels extends StatelessWidget {
  const _RawPanels({required this.latest, required this.isMobile});

  final SensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = !isMobile && constraints.maxWidth > 1000;
        final double width = wide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth;
        final double spacing = isMobile ? 10 : 12;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            _RawCard(
              title: 'Soil Moisture',
              value: latest.soilVoltage != null
                  ? '${latest.soilVoltage!.toStringAsFixed(2)} V'
                  : '—',
              color: scheme.primary,
              width: width,
              isMobile: isMobile,
            ),
            _RawCard(
              title: 'UV Sensor',
              value: latest.uvVoltage != null
                  ? '${latest.uvVoltage!.toStringAsFixed(2)} V'
                  : '—',
              color: const Color(0xFFFFC107),
              width: width,
              isMobile: isMobile,
            ),
            _RawCard(
              title: 'Gas Sensor',
              value: latest.mqVoltage != null
                  ? '${latest.mqVoltage!.toStringAsFixed(2)} V'
                  : '—',
              color: const Color(0xFF9C27B0),
              width: width,
              isMobile: isMobile,
            ),
          ],
        );
      },
    );
  }
}

class _RawCard extends StatelessWidget {
  const _RawCard({
    required this.title,
    required this.value,
    required this.color,
    required this.width,
    required this.isMobile,
  });

  final String title;
  final String value;
  final Color color;
  final double width;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        elevation: 2,
        shadowColor: color.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
          side: BorderSide(
            color: color.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                color.withOpacity(0.08),
                color.withOpacity(0.03),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendGrid extends StatelessWidget {
  const _TrendGrid({required this.readings, required this.isMobile});

  final List<SensorReading> readings;
  final bool isMobile;

  List<TrendPoint> _map(List<SensorReading> source, double? Function(SensorReading) selector) {
    return source
        .where((SensorReading r) => selector(r) != null)
        .map((SensorReading r) => TrendPoint(r.displayTime, selector(r)!))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = !isMobile && constraints.maxWidth > 1100;
        final double width = wide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        final double spacing = isMobile ? 12 : 16;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Temperature (°C)',
                unit: '°C',
                color: const Color(0xFFFF6B35),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.temperature),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Humidity (%)',
                unit: '%',
                color: const Color(0xFF2196F3),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.humidity),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Soil Voltage (V)',
                unit: 'V',
                color: const Color(0xFF8B4513),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.soilVoltage),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'Gas Voltage (V)',
                unit: 'V',
                color: const Color(0xFF9C27B0),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.mqVoltage),
              ),
            ),
            SizedBox(
              width: width,
              child: TrendChart(
                title: 'UV Voltage (V)',
                unit: 'V',
                color: const Color(0xFFFFC107),
                optimalMin: null,
                optimalMax: null,
                points: _map(readings, (SensorReading r) => r.uvVoltage),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

// Start of EOSM
class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction, required this.isMobile});

  final EosmStressPrediction prediction;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color stressColor = prediction.stressColor;
    
    return Card(
      elevation: 3,
      shadowColor: stressColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        side: BorderSide(
          color: stressColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              stressColor.withOpacity(0.05),
              stressColor.withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 14 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.all(isMobile ? 6 : 8),
                    decoration: BoxDecoration(
                      color: stressColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                    ),
                    child: Icon(Icons.psychology, color: stressColor, size: isMobile ? 20 : 24),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      'ML Stress Prediction',
                      style: (isMobile ? textTheme.titleMedium : textTheme.titleLarge)?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Row(
                children: <Widget>[
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: stressColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                      border: Border.all(
                        color: stressColor.withOpacity(0.4),
                        width: isMobile ? 1.5 : 2,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: stressColor.withOpacity(0.2),
                          blurRadius: isMobile ? 6 : 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      prediction.stressLabel,
                      style: (isMobile ? textTheme.titleMedium : textTheme.titleLarge)?.copyWith(
                        color: stressColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: isMobile ? 1.0 : 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Expanded(
                    child: Text(
                      '${(prediction.highestProbability * 100).toStringAsFixed(1)}% confidence',
                      style: (isMobile ? textTheme.bodyMedium : textTheme.bodyLarge)?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (prediction.stressProbabilities.isNotEmpty) ...<Widget>[
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  'Probabilities:',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                Wrap(
                  spacing: isMobile ? 8 : 10,
                  runSpacing: isMobile ? 6 : 8,
                  children: prediction.stressProbabilities.entries.map((entry) {
                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 10 : 12,
                        vertical: isMobile ? 6 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${entry.key}: ${(entry.value * 100).toStringAsFixed(1)}%',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile ? 12 : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
class _ModernHeader extends StatelessWidget {
  const _ModernHeader({
    required this.selectedGreenhouse,
    required this.lastUpdated,
    required this.baseStationId,
    required this.scheme,
    required this.greenhouseOptions,
    required this.greenhouseStations,
    required this.onSelect,
    required this.isMobile,
  });

  final String selectedGreenhouse;
  final DateTime? lastUpdated;
  final String? baseStationId;
  final ColorScheme scheme;
  final List<String> greenhouseOptions;
  final Map<String, String?> greenhouseStations;
  final ValueChanged<String?> onSelect;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final String formatted = lastUpdated != null
        ? _formatDateTime(lastUpdated!, isMobile: isMobile)
        : 'Waiting for first reading';
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF4CAF50).withOpacity(0.1),
            const Color(0xFF81C784).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule,
                          size: isMobile ? 16 : 18,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatted,
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.local_florist,
                  color: Color(0xFF4CAF50),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.location_on, size: 18, color: const Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nuwara Eliya · Sri Lanka',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: DropdownButtonFormField<String>(
              value: greenhouseOptions.contains(selectedGreenhouse)
                  ? selectedGreenhouse
                  : greenhouseOptions.firstOrNull,
              items: greenhouseOptions
                  .map(
                    (String id) => DropdownMenuItem<String>(
                      value: id,
                      child: Text(
                        id == 'ALL'
                            ? 'All Greenhouses'
                            : '$id${greenhouseStations[id] != null ? ' · ${greenhouseStations[id]}' : ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onSelect,
              decoration: InputDecoration(
                labelText: 'Select Greenhouse',
                prefixIcon: const Icon(Icons.agriculture, color: Color(0xFF4CAF50)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF4CAF50).withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
      );
    }
}

class _ModernPredictionCard extends StatelessWidget {
  const _ModernPredictionCard({
    required this.prediction,
    required this.latest,
    required this.isMobile,
  });

  final EosmStressPrediction prediction;
  final SensorReading latest;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final Color stressColor = prediction.stressColor;
    final String recommendation = _getRecommendation(prediction.stressLabel);
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            stressColor.withOpacity(0.15),
            stressColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stressColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: stressColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.psychology, color: stressColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Plant Stress Level',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prediction.stressLabel,
                      style: TextStyle(
                        fontSize: isMobile ? 28 : 36,
                        fontWeight: FontWeight.bold,
                        color: stressColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      '${(prediction.highestProbability * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: isMobile ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        color: stressColor,
                      ),
                    ),
                    Text(
                      'Confidence',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.lightbulb_outline, color: stressColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (prediction.stressProbabilities.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              'Probability Breakdown',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: prediction.stressProbabilities.entries.map((entry) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          '${(entry.value * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: stressColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: metric.color.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: metric.color.withOpacity(0.15),
          width: 1.5,
        ),
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
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: metric.color.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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


