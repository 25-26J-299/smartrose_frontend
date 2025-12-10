// File: smartrose_frontend/lib/screens/home_screen.dart

// Purpose: Display INM sensor readings

import 'package:flutter/material.dart';

import '../services/inm_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final INMService _inmService = INMService();
  List<Map<String, dynamic>> readings = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSensorData();
  }

  Future<void> _loadSensorData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await _inmService.fetchSensorReadings();

    setState(() {
      isLoading = false;
      if (result['success'] == true) {
        readings = List<Map<String, dynamic>>.from(result['data']);
        errorMessage = null;
      } else {
        readings = [];
        errorMessage = result['error'] ?? 'Unknown error occurred';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('INM Sensor Readings')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadSensorData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading sensor data...'),
          ],
        ),
      );
    }

    // Error state
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to load sensor data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                '💡 Tips:\n'
                '• Make sure your backend is running at localhost:8000\n'
                '• Check if CORS is enabled on your backend\n'
                '• Verify the API endpoint is correct',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSensorData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (readings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sensors_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No sensor readings available',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no INM sensor readings yet.\nTry adding some data to your backend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSensorData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Data state
    return RefreshIndicator(
      onRefresh: _loadSensorData,
      child: ListView.builder(
        itemCount: readings.length,
        itemBuilder: (context, index) {
          final reading = readings[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.sensors),
              ),
              title: Text('Sensor: ${reading['sensor_id'] ?? 'N/A'}'),
              subtitle: Text(
                'Temp: ${reading['temperature'] ?? 'N/A'}°C\n'
                'Humidity: ${reading['humidity'] ?? 'N/A'}%\n'
                'Soil Moisture: ${reading['soil_moisture'] ?? 'N/A'}%',
              ),
              trailing: reading['timestamp'] != null
                  ? Text(
                      '${DateTime.tryParse(reading['timestamp'])?.toLocal() ?? reading['timestamp']}',
                      style: const TextStyle(fontSize: 12),
                    )
                  : null,
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}
