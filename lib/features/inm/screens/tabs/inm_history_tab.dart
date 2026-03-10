// File: lib/features/inm/screens/tabs/inm_history_tab.dart
// Purpose: History tab - mobile-first activity timeline + trend charts (2026 design)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/inm_action_history.dart';
import '../../models/inm_status.dart';
import '../../services/inm_api_service.dart';

class InmHistoryTab extends StatefulWidget {
  /// [deviceId] and [token] scope all API calls to the selected INM device.
  const InmHistoryTab({
    super.key,
    required this.deviceId,
    required this.token,
    this.refreshNotifier,
  });

  final String deviceId;
  final String token;
  final ValueNotifier<int>? refreshNotifier;

  @override
  State<InmHistoryTab> createState() => _InmHistoryTabState();
}

class _InmHistoryTabState extends State<InmHistoryTab>
    with AutomaticKeepAliveClientMixin {
  final InmApiService _apiService = InmApiService();

  List<InmActionHistory>? _actionHistory;
  InmStatus? _status;
  bool _isLoadingActions = true;
  DateTime? _selectedDate = DateTime.now();
  
  // Auto-refresh
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _actionHistory = [];
    _loadData();
    _startAutoRefresh();
    widget.refreshNotifier?.addListener(_onManualRefresh);
  }

  void _onManualRefresh() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    widget.refreshNotifier?.removeListener(_onManualRefresh);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        if (mounted) {
          _loadData(showLoading: false);
        }
      },
    );
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingActions = true;
      });
    }

    await Future.wait([
      _loadActionHistory(),
      _loadStatus(),
    ]);
  }

  Future<void> _loadActionHistory() async {
    try {
      final actions = await _apiService.fetchActionHistory(
          widget.deviceId, widget.token);
      if (mounted) {
        setState(() {
          _actionHistory = actions;
          _isLoadingActions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actionHistory = [];
          _isLoadingActions = false;
        });
      }
    }
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _apiService.fetchStatus(widget.deviceId, widget.token);
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (!_isLoadingActions && _status != null && !_status!.hasSensorData) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sensors_off,
                      size: 48,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No data available',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Activity Timeline',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    _selectedDate == null
                        ? 'All dates'
                        : DateFormat('dd MMM yyyy').format(_selectedDate!),
                  ),
                ),
                if (_selectedDate != null)
                  IconButton(
                    tooltip: 'Show all dates',
                    onPressed: () {
                      setState(() {
                        _selectedDate = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            Text(
              _selectedDate == null
                  ? 'Showing all activity records'
                  : 'Showing records for ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            _buildActivityTimeline(theme),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTimeline(ThemeData theme) {
    if (_isLoadingActions) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filteredActions = _selectedDate == null
        ? (_actionHistory ?? [])
        : (_actionHistory ?? [])
            .where((action) => _isSameDay(action.timestamp, _selectedDate!))
            .toList();

    if (filteredActions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedDate == null
                    ? 'No activity history yet'
                    : 'No records for ${DateFormat('dd MMM yyyy').format(_selectedDate!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build timeline with action history
    return Column(
      children: filteredActions.asMap().entries.map((entry) {
        final index = entry.key;
        final action = entry.value;
        final isLast = index == filteredActions.length - 1;
        
        return _TimelineItem(
          action: action,
          isLast: isLast,
        );
      }).toList(),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _selectedDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Select history date',
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class _TimelineItem extends StatefulWidget {
  final InmActionHistory action;
  final bool isLast;

  const _TimelineItem({
    super.key,
    required this.action,
    required this.isLast,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  bool _isExpanded = false;

  // Friendly relative timestamp: "Today 2:30 PM", "Yesterday 10:15 AM", "Mon 3 Mar 9:00 AM"
  String _friendlyTime(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(ts.year, ts.month, ts.day);
    final diff = today.difference(day).inDays;
    final time = DateFormat('h:mm a').format(ts);
    if (diff == 0) return 'Today  $time';
    if (diff == 1) return 'Yesterday  $time';
    if (diff < 7) return '${DateFormat('EEE').format(ts)}  $time';
    return DateFormat('dd MMM yyyy  h:mm a').format(ts);
  }

  // ---------------------------------------------------------------------------
  // Data helpers
  // ---------------------------------------------------------------------------

  // Extract one labelled section from the combined recommendationText.
  // Format stored by saveAction:
  //   "EC Action: ...\n\npH Action: ...\n\nNPK Recommendation: ..."
  String _extractSection(String fullText, String prefix) {
    if (fullText.isEmpty) return '';
    final idx = fullText.indexOf(prefix);
    if (idx == -1) return '';
    final after = fullText.substring(idx + prefix.length).trim();
    final next = after.indexOf('\n\n');
    return next == -1 ? after.trim() : after.substring(0, next).trim();
  }

  // Resolve a field: use direct value when it is real data,
  // otherwise fall back to parsing it from the combined recommendationText.
  String _resolve(String direct, String fallbackPrefix, String fullText) {
    const placeholders = [
      'No EC action available',
      'No pH action available',
      'No NPK recommendation available',
    ];
    final clean = direct.trim();
    if (clean.isNotEmpty && !placeholders.contains(clean)) return clean;
    final parsed = _extractSection(fullText, fallbackPrefix);
    return parsed.isNotEmpty ? parsed : '—';
  }

  // Return the first sentence only (up to 80 chars) of an action string
  String _shortAction(String? text) {
    if (text == null || text.isEmpty || text == '—') return '—';
    final stripped = text.trim();
    final dot = stripped.indexOf('. ');
    final snippet = dot > 0 && dot < 80 ? stripped.substring(0, dot + 1) : stripped;
    return snippet.length > 90 ? '${snippet.substring(0, 88)}…' : snippet;
  }

  // Derive action badge (↑ Increase / ↓ Decrease / ✓ Maintain / ⟳ Adjust)
  ({String label, IconData icon, Color color}) _actionBadge(
      String? text, Color fallback) {
    if (text == null) return (label: '—', icon: Icons.remove, color: Colors.grey);
    final lower = text.toLowerCase();
    if (lower.contains('increase') || lower.contains('add') || lower.contains('top up'))
      return (label: 'Increase', icon: Icons.arrow_upward_rounded, color: Colors.orange.shade700);
    if (lower.contains('decrease') || lower.contains('reduce') ||
        lower.contains('dilute') || lower.contains('lower') || lower.contains('flush'))
      return (label: 'Decrease', icon: Icons.arrow_downward_rounded, color: Colors.blue.shade700);
    if (lower.contains('maintain') || lower.contains('no action') ||
        lower.contains('optimal') || lower.contains('stable'))
      return (label: 'Maintain', icon: Icons.check_rounded, color: Colors.green.shade700);
    if (lower.contains('adjust') || lower.contains('correct') || lower.contains('balance'))
      return (label: 'Adjust', icon: Icons.tune_rounded, color: Colors.amber.shade800);
    if (lower.contains('monitor') || lower.contains('watch'))
      return (label: 'Monitor', icon: Icons.visibility_outlined, color: Colors.teal.shade700);
    return (label: 'Review', icon: Icons.info_outline_rounded, color: fallback);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = widget.action;
    final isApplied = action.actionTaken == 'applied';

    final cardColor = isApplied ? Colors.green : Colors.orange;
    final fullText = action.recommendationText ?? '';

    // Resolve each field — use structured field when available,
    // otherwise parse from the combined recommendationText (legacy records).
    final ecText  = _resolve(action.ecAction, 'EC Action:', fullText);
    final phText  = _resolve(action.phAction, 'pH Action:', fullText);
    final npkText = _resolve(
        action.npkRecommendation, 'NPK Recommendation:', fullText);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Timeline spine ──────────────────────────────────────────────────
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: cardColor.withOpacity(0.35), width: 2),
              ),
              child: Icon(
                isApplied ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                color: cardColor,
                size: 20,
              ),
            ),
            if (!widget.isLast)
              Container(
                width: 2,
                height: 8,
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
          ],
        ),

        const SizedBox(width: 12),

        // ── Card ────────────────────────────────────────────────────────────
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: cardColor.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card header ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.07),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isApplied
                                  ? Icons.check_circle_rounded
                                  : Icons.do_not_disturb_on_rounded,
                              size: 13,
                              color: cardColor.shade700,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isApplied
                                  ? 'Fertilizer Applied'
                                  : 'Recommendation Skipped',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cardColor.shade700,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _friendlyTime(action.timestamp),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Structured recommendation rows ──────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Column(
                    children: [
                      _RecRow(
                        icon: Icons.electric_bolt_rounded,
                        iconColor: Colors.purple,
                        label: 'EC Level',
                        shortAction: _shortAction(ecText),
                        badge: _actionBadge(ecText, Colors.purple),
                      ),
                      const SizedBox(height: 8),
                      _RecRow(
                        icon: Icons.science_rounded,
                        iconColor: Colors.teal,
                        label: 'pH Balance',
                        shortAction: _shortAction(phText),
                        badge: _actionBadge(phText, Colors.teal),
                      ),
                      const SizedBox(height: 8),
                      _RecRow(
                        icon: Icons.eco_rounded,
                        iconColor: Colors.green.shade700,
                        label: 'Nutrients (NPK)',
                        shortAction: _shortAction(npkText),
                        badge: _actionBadge(npkText, Colors.green.shade700),
                      ),
                    ],
                  ),
                ),

                // ── Footer: growth stage + full-details toggle ──────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (action.growthStage != null) ...[
                            Icon(Icons.local_florist_outlined,
                                size: 13,
                                color: theme.colorScheme.primary
                                    .withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              '${action.growthStage![0].toUpperCase()}'
                              '${action.growthStage!.substring(1).toLowerCase()} stage',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (fullText.isNotEmpty) ...[
                            const Spacer(),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _isExpanded ? 'Hide details' : 'Full details',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_isExpanded && fullText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.15),
                            ),
                          ),
                          child: Text(
                            fullText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.72),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Compact row showing one recommendation category (EC / pH / NPK)
class _RecRow extends StatelessWidget {
  const _RecRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.shortAction,
    required this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String shortAction;
  final ({String label, IconData icon, Color color}) badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label + action badge on same line
              Row(
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badge.icon, size: 10, color: badge.color),
                        const SizedBox(width: 3),
                        Text(
                          badge.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: badge.color,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                shortAction,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
