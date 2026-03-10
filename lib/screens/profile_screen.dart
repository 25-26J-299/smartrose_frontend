import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_routes.dart';
import '../core/auth/auth_state.dart';
import '../services/auth_service.dart';
import '../shared/widgets/gradient_header.dart';
import 'profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  bool _loading = true;
  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _baseStations = [];
  List<Map<String, dynamic>> _locations = [];

  Future<void> _loadData() async {
    final String? token = context.read<AuthState>().token;
    if (token == null) {
      setState(() {
        _loading = false;
        _devices = [];
        _baseStations = [];
        _locations = [];
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final List<Map<String, dynamic>> devices =
          await _authService.fetchMyDevices(token);
      final List<Map<String, dynamic>> baseStations =
          await _authService.fetchMyBaseStations(token);
      final List<Map<String, dynamic>> locations =
          await _authService.fetchMyLocations(token);
      if (mounted) {
        setState(() {
          _devices = devices;
          _baseStations = baseStations;
          _locations = locations;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _devices = [];
          _baseStations = [];
          _locations = [];
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final AuthState auth = context.read<AuthState>();
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = context.watch<AuthState>();
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerHighest,
      appBar: GradientHeader.buildAppBar(
        context: context,
        title: 'Profile',
        showBackButton: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildProfileHeader(auth, scheme),
                      _buildSection(
                        scheme,
                        title: 'Locations',
                        icon: Icons.location_on_outlined,
                        items: _locations,
                        itemTitle: (m) =>
                            (m['name'] as String?) ?? 'Unnamed location',
                        itemSubtitle: (m) =>
                            (m['address'] as String?) ??
                            (m['type'] as String?) ??
                            '',
                      ),
                      _buildBaseStationsAndDevices(scheme),
                      _buildLogout(scheme),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(AuthState auth, ColorScheme scheme) {
    final String userName = auth.user?.name ?? auth.user?.fullName ?? 'User';
    final String userEmail = auth.user?.email ?? '';

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    userName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                  ),
                  if (userEmail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditProfileScreen(),
                  ),
                ).then((_) => _loadData());
              },
              tooltip: 'Edit profile',
              color: scheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  String _deviceName(Map<String, dynamic> m) {
    final String? name = m['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    final String? type = m['type'] as String?;
    if (type != null && type.trim().isNotEmpty) return type;
    return 'Device';
  }

  String _deviceSerial(Map<String, dynamic> m) {
    return (m['device_serial_number'] as String?) ??
        (m['device_id'] as String?) ??
        (m['serial'] as String?) ??
        '';
  }

  String _baseStationName(Map<String, dynamic> m) {
    final String? name = m['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Base station';
  }

  String _baseStationSerial(Map<String, dynamic> m) {
    return (m['serial'] as String?)?.toString() ?? '';
  }

  Widget _buildBaseStationsAndDevices(ColorScheme scheme) {
    final List<Map<String, dynamic>> devicesWithoutBs = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> d in _devices) {
      final Object? bsId = d['base_station_id'];
      if (bsId == null || bsId.toString().trim().isEmpty) {
        devicesWithoutBs.add(d);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.router_outlined, color: scheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Base stations & devices',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_baseStations.isEmpty && devicesWithoutBs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'None',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ..._baseStations.asMap().entries.expand(
                      (MapEntry<int, Map<String, dynamic>> e) {
                        final int i = e.key;
                        final Map<String, dynamic> bs = e.value;
                        return <Widget>[
                          if (i > 0) const Divider(height: 24),
                          _buildBaseStationRow(bs, scheme),
                          ..._devicesForBaseStation(bs).map(
                          (Map<String, dynamic> d) =>
                              _buildDeviceIndent(d, scheme, indent: true),
                          ),
                          const SizedBox(height: 4),
                        ];
                      },
                    ),
                    if (devicesWithoutBs.isNotEmpty) ...[
                      if (_baseStations.isNotEmpty)
                        const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Devices without base station',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      ...devicesWithoutBs.map(
                        (Map<String, dynamic> d) =>
                            _buildDeviceIndent(d, scheme, indent: false),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _devicesForBaseStation(
    Map<String, dynamic> baseStation,
  ) {
    final String bsId = (baseStation['_id'] as Object?).toString();
    if (bsId.isEmpty) return <Map<String, dynamic>>[];
    return _devices.where((Map<String, dynamic> d) {
      final Object? id = d['base_station_id'];
      return id != null && id.toString() == bsId;
    }).toList();
  }

  Widget _buildBaseStationRow(
    Map<String, dynamic> bs,
    ColorScheme scheme,
  ) {
    final String name = _baseStationName(bs);
    final String serial = _baseStationSerial(bs);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.router_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (serial.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    serial,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceIndent(
    Map<String, dynamic> d,
    ColorScheme scheme, {
    bool indent = true,
  }) {
    final String name = _deviceName(d);
    final String serial = _deviceSerial(d);
    return Padding(
      padding: EdgeInsets.only(
        left: indent ? 44 : 0,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.sensors_outlined,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (serial.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    serial,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    ColorScheme scheme, {
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) itemTitle,
    required String Function(Map<String, dynamic>) itemSubtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, color: scheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'None',
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...items.map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                itemTitle(m),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (itemSubtitle(m).isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  itemSubtitle(m),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
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
          ),
        ),
      ),
    );
  }

  Widget _buildLogout(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: scheme.outline),
          ),
        ),
      ),
    );
  }
}
