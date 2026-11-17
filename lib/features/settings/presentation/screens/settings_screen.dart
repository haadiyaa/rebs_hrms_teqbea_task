import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/services/location_simulator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../attendance/presentation/providers/attendance_notifier.dart';
import '../../../employee/presentation/providers/employee_notifier.dart';
import '../../../leave/presentation/providers/leave_notifier.dart';
import '../../../sync/presentation/providers/sync_notifier.dart';

/// Settings screen allowing reviewers and users to configure runtime API URL,
/// test connectivity, review geofence parameters, and control mock server scenarios.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _customLatController;
  late final TextEditingController _customLngController;
  bool _isTestingConnection = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(appConfigProvider);
    _urlController = TextEditingController(text: config.apiBaseUrl);
    _customLatController = TextEditingController(text: config.officeLatitude.toString());
    _customLngController = TextEditingController(text: config.officeLongitude.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _customLatController.dispose();
    _customLngController.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl(String newUrl) async {
    await ref.read(appConfigProvider.notifier).updateBaseUrl(newUrl);
    _urlController.text = newUrl;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API Base URL updated to: $newUrl'),
          backgroundColor: AppTheme.statusSuccess,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _testResult = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      await client.get('/employee/me');
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testSuccess = true;
          _testResult = 'Connection successful! (Mock server active)';
        });
        // Also refresh employee and attendance data
        await ref.read(employeeNotifierProvider.notifier).loadEmployee(forceRefresh: true);
        await ref.read(attendanceNotifierProvider.notifier).loadDashboardAttendance(forceRefresh: true);
        await ref.read(leaveNotifierProvider.notifier).loadLeaveData(forceRefresh: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
          _testSuccess = false;
          _testResult = 'Connection failed: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _setMockScenario(String scenario) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/__admin/scenario', body: {'scenario': scenario});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mock scenario switched to: "$scenario"'),
            backgroundColor: AppTheme.primaryBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not set scenario (Is server running?): $e'),
            backgroundColor: AppTheme.statusError,
          ),
        );
      }
    }
  }

  Future<void> _resetMockServer() async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/__admin/reset', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mock server state reset to default'),
            backgroundColor: AppTheme.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reset server: $e'),
            backgroundColor: AppTheme.statusError,
          ),
        );
      }
    }
  }

  Future<void> _showEditOfficeDialog(BuildContext context, AppConfig appConfig) async {
    final latController = TextEditingController(text: appConfig.officeLatitude.toString());
    final lngController = TextEditingController(text: appConfig.officeLongitude.toString());
    final radiusController = TextEditingController(text: appConfig.officeRadiusMeters.toInt().toString());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Office Geofence'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: latController,
                decoration: const InputDecoration(labelText: 'Office Latitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lngController,
                decoration: const InputDecoration(labelText: 'Office Longitude'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(labelText: 'Radius (meters)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newLat = double.tryParse(latController.text.trim());
              final newLng = double.tryParse(lngController.text.trim());
              final newRadius = double.tryParse(radiusController.text.trim());

              if (newLat != null && newLng != null && newRadius != null) {
                // Update local app config
                ref.read(appConfigProvider.notifier).updateOfficeGeofence(
                      latitude: newLat,
                      longitude: newLng,
                      radiusMeters: newRadius,
                    );

                // Update backend mock server if reachable
                try {
                  final client = ref.read(apiClientProvider);
                  await client.post('/__admin/office', body: {
                    'latitude': newLat,
                    'longitude': newLng,
                    'radiusMeters': newRadius,
                  });
                } catch (_) {}

                // Refresh employee profile
                await ref.read(employeeNotifierProvider.notifier).loadEmployee(forceRefresh: true);

                if (mounted && ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Office location updated: ($newLat, $newLng) ${newRadius.toInt()}m'),
                      backgroundColor: AppTheme.statusSuccess,
                    ),
                  );
                }
              }
            },
            child: const Text('Save & Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = ref.watch(appConfigProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final simulatorState = ref.watch(locationSimulatorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings & Configuration',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Section 1: API Endpoint Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dns_outlined, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Backend API Base URL',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configure without rebuilding. Supports ngrok URLs or local host network loopback.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'http://10.0.2.2:3000',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AppTheme.primaryBlue),
                        onPressed: () => _saveBaseUrl(_urlController.text),
                        tooltip: 'Save URL',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Quick Presets:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.phone_android, size: 16),
                        label: const Text('Android (10.0.2.2:3000)'),
                        onPressed: () => _saveBaseUrl('http://10.0.2.2:3000'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.computer, size: 16),
                        label: const Text('Localhost (localhost:3000)'),
                        onPressed: () => _saveBaseUrl('http://localhost:3000'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _isTestingConnection ? null : _testConnection,
                      icon: _isTestingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.network_check, size: 18),
                      label: const Text('Test Connection'),
                    ),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _testSuccess
                            ? AppTheme.statusSuccess.withValues(alpha: 0.1)
                            : AppTheme.statusError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _testSuccess ? Icons.check_circle : Icons.error_outline,
                            color: _testSuccess ? AppTheme.statusSuccess : AppTheme.statusError,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _testSuccess ? AppTheme.statusSuccess : AppTheme.statusError,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Mock Server Scenario Admin
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.science_outlined, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Mock Server Scenarios',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Simulate network & server conditions on the Node.js mock backend:',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton(
                        onPressed: () => _setMockScenario('success'),
                        child: const Text('Success (Normal)'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setMockScenario('slow'),
                        child: const Text('Slow (3s Delay)'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setMockScenario('timeout'),
                        child: const Text('Timeout (12s)'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setMockScenario('server_error'),
                        child: const Text('500 Error'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setMockScenario('duplicate_conflict'),
                        child: const Text('409 Conflict'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setMockScenario('leave_rejection'),
                        child: const Text('Leave 422 Reject'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _resetMockServer,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset Mock Server State'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2.5: GPS Location Simulator (Debug Testing Only)
          if (kDebugMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.gps_fixed, color: Color(0xFF7C3AED)),
                            SizedBox(width: 8),
                            Text(
                              'GPS Location Simulator',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Switch(
                          value: simulatorState.isEnabled,
                          onChanged: (val) {
                            ref.read(locationSimulatorProvider.notifier).toggle(
                                  val,
                                  officeLat: appConfig.officeLatitude,
                                  officeLng: appConfig.officeLongitude,
                                );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Simulate device coordinates for testing 200m geofence on emulators without GPS spoofing tools.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    if (simulatorState.isEnabled) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Reviewer Simulation Presets:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('At Office (0m) [✅ Allow]'),
                            selected: simulatorState.activePreset == LocationSimulatorPreset.office0m,
                            onSelected: (_) {
                              ref.read(locationSimulatorProvider.notifier).setPreset(
                                    LocationSimulatorPreset.office0m,
                                    officeLat: appConfig.officeLatitude,
                                    officeLng: appConfig.officeLongitude,
                                  );
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Inside (~150m) [✅ Allow]'),
                            selected: simulatorState.activePreset == LocationSimulatorPreset.inside150m,
                            onSelected: (_) {
                              ref.read(locationSimulatorProvider.notifier).setPreset(
                                    LocationSimulatorPreset.inside150m,
                                    officeLat: appConfig.officeLatitude,
                                    officeLng: appConfig.officeLongitude,
                                  );
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Exact (200m) [✅ Allow]'),
                            selected: simulatorState.activePreset == LocationSimulatorPreset.boundary200m,
                            onSelected: (_) {
                              ref.read(locationSimulatorProvider.notifier).setPreset(
                                    LocationSimulatorPreset.boundary200m,
                                    officeLat: appConfig.officeLatitude,
                                    officeLng: appConfig.officeLongitude,
                                  );
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Outside (~280m) [❌ Reject]'),
                            selected: simulatorState.activePreset == LocationSimulatorPreset.outside280m,
                            onSelected: (_) {
                              ref.read(locationSimulatorProvider.notifier).setPreset(
                                    LocationSimulatorPreset.outside280m,
                                    officeLat: appConfig.officeLatitude,
                                    officeLng: appConfig.officeLongitude,
                                  );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (simulatorState.calculatedDistanceMeters ?? 0) <= appConfig.officeRadiusMeters
                              ? AppTheme.statusSuccess.withValues(alpha: 0.1)
                              : AppTheme.statusRejected.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (simulatorState.calculatedDistanceMeters ?? 0) <= appConfig.officeRadiusMeters
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: (simulatorState.calculatedDistanceMeters ?? 0) <= appConfig.officeRadiusMeters
                                  ? AppTheme.statusSuccess
                                  : AppTheme.statusRejected,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Distance: ~${(simulatorState.calculatedDistanceMeters ?? 0).toStringAsFixed(1)}m from office (${(simulatorState.calculatedDistanceMeters ?? 0) <= appConfig.officeRadiusMeters ? "Inside 200m - Permitted" : "Outside 200m - Rejected"})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: (simulatorState.calculatedDistanceMeters ?? 0) <= appConfig.officeRadiusMeters
                                      ? AppTheme.statusSuccess
                                      : AppTheme.statusRejected,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customLatController,
                              decoration: const InputDecoration(labelText: 'Custom Lat'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _customLngController,
                              decoration: const InputDecoration(labelText: 'Custom Lng'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final lat = double.tryParse(_customLatController.text.trim());
                              final lng = double.tryParse(_customLngController.text.trim());
                              if (lat != null && lng != null) {
                                ref.read(locationSimulatorProvider.notifier).setCustomLocation(
                                      lat,
                                      lng,
                                      officeLat: appConfig.officeLatitude,
                                      officeLng: appConfig.officeLongitude,
                                    );
                              }
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 3: Geofence & Office Policy Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.location_on_outlined, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Text(
                            'Office Geofence & Policies',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showEditOfficeDialog(context, appConfig),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Office Latitude', appConfig.officeLatitude.toStringAsFixed(6)),
                  _buildInfoRow('Office Longitude', appConfig.officeLongitude.toStringAsFixed(6)),
                  _buildInfoRow('Geofence Radius', '${appConfig.officeRadiusMeters.toInt()} meters'),
                  _buildInfoRow('Company Timezone', appConfig.companyTimezone),
                  if (appConfig.mockLatitude != null && appConfig.mockLongitude != null)
                    _buildInfoRow(
                      'Simulator Mock Location',
                      '${appConfig.mockLatitude}, ${appConfig.mockLongitude}',
                      isHighlighted: true,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Sync Engine Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sync, color: AppTheme.primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Sync Engine Status',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('Engine Status', syncState.isSyncing ? 'Syncing...' : 'Idle'),
                  _buildInfoRow('Pending Queue Items', '${syncState.pendingCount} events'),
                  if (syncState.errorMessage != null)
                    _buildInfoRow('Last Error', syncState.errorMessage!, isError: true),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: syncState.isSyncing
                          ? null
                          : () => ref.read(syncNotifierProvider.notifier).syncNow(),
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Force Sync Queue Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // About app
          const Center(
            child: Column(
              children: [
                Text(
                  'REBS HRMS Workspace v1.0.0',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textDark),
                ),
                SizedBox(height: 4),
                Text(
                  'Clean Architecture • Riverpod • SQLite • Offline-First',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false, bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError
                    ? AppTheme.statusError
                    : isHighlighted
                        ? AppTheme.primaryBlue
                        : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
