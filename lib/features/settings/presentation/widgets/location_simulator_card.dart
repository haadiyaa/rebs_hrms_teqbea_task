import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/services/location_simulator.dart';
import '../../../../core/theme/app_theme.dart';

/// Clean, responsive, and robust debug card for reviewing the 200m GPS geofence.
/// Guarded strictly by [kDebugMode] — invisible and inactive in release builds.
class LocationSimulatorCard extends ConsumerStatefulWidget {
  final AppConfig appConfig;

  const LocationSimulatorCard({
    super.key,
    required this.appConfig,
  });

  @override
  ConsumerState<LocationSimulatorCard> createState() =>
      _LocationSimulatorCardState();
}

class _LocationSimulatorCardState extends ConsumerState<LocationSimulatorCard> {
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  @override
  void initState() {
    super.initState();
    _latController = TextEditingController(
      text: widget.appConfig.officeLatitude.toStringAsFixed(6),
    );
    _lngController = TextEditingController(
      text: widget.appConfig.officeLongitude.toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final simulatorState = ref.watch(locationSimulatorProvider);
    final notifier = ref.read(locationSimulatorProvider.notifier);
    final officeLat = widget.appConfig.officeLatitude;
    final officeLng = widget.appConfig.officeLongitude;
    final radius = widget.appConfig.officeRadiusMeters;

    final dist = simulatorState.calculatedDistanceMeters ?? 0.0;
    final isWithinGeofence = dist <= radius;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: simulatorState.isEnabled
              ? const Color(0xFFDDD6FE)
              : const Color(0xFFE2E8F0),
          width: simulatorState.isEnabled ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header with Title & Enable Switch
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.gps_fixed,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GPS Location Simulator',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Debug reviewer tool for 200m geofence',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: simulatorState.isEnabled,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: (enabled) {
                    notifier.toggle(
                      enabled,
                      officeLat: officeLat,
                      officeLng: officeLng,
                    );
                  },
                ),
              ],
            ),

            // If simulator is active, render controls
            if (simulatorState.isEnabled) ...[
              const Divider(height: 24),

              // 2. Status & Distance Feedback Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isWithinGeofence
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWithinGeofence
                        ? const Color(0xFFBBF7D0)
                        : const Color(0xFFFECACA),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isWithinGeofence
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: isWithinGeofence
                          ? AppTheme.statusSuccess
                          : AppTheme.statusRejected,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isWithinGeofence
                                    ? 'Within 200m (Permitted)'
                                    : 'Outside 200m (Rejected)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isWithinGeofence
                                      ? AppTheme.statusSuccess
                                      : AppTheme.statusRejected,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '~${dist.toStringAsFixed(1)} m',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isWithinGeofence
                                      ? AppTheme.statusSuccess
                                      : AppTheme.statusRejected,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Active: ${simulatorState.activePreset.label} (${simulatorState.simulatedLatitude?.toStringAsFixed(5)}, ${simulatorState.simulatedLongitude?.toStringAsFixed(5)})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Reviewer Presets Heading
              const Text(
                'Reviewer Simulation Presets:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),

              // 4. Clean Preset Buttons
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PresetButton(
                          label: 'At Office (0m)',
                          verdict: '✅ Allow',
                          isSelected: simulatorState.activePreset ==
                              LocationSimulatorPreset.office0m,
                          onTap: () => notifier.setPreset(
                            LocationSimulatorPreset.office0m,
                            officeLat: officeLat,
                            officeLng: officeLng,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PresetButton(
                          label: 'Inside (~150m)',
                          verdict: '✅ Allow',
                          isSelected: simulatorState.activePreset ==
                              LocationSimulatorPreset.inside150m,
                          onTap: () => notifier.setPreset(
                            LocationSimulatorPreset.inside150m,
                            officeLat: officeLat,
                            officeLng: officeLng,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _PresetButton(
                          label: 'Boundary (200m)',
                          verdict: '✅ Allow',
                          isSelected: simulatorState.activePreset ==
                              LocationSimulatorPreset.boundary200m,
                          onTap: () => notifier.setPreset(
                            LocationSimulatorPreset.boundary200m,
                            officeLat: officeLat,
                            officeLng: officeLng,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PresetButton(
                          label: 'Outside (~280m)',
                          verdict: '❌ Reject',
                          isSelected: simulatorState.activePreset ==
                              LocationSimulatorPreset.outside280m,
                          isReject: true,
                          onTap: () => notifier.setPreset(
                            LocationSimulatorPreset.outside280m,
                            officeLat: officeLat,
                            officeLng: officeLng,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 5. Custom Coordinates
              const Text(
                'Custom Coordinates:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lngController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      final lat = double.tryParse(_latController.text.trim());
                      final lng = double.tryParse(_lngController.text.trim());
                      if (lat != null && lng != null) {
                        notifier.setCustomLocation(
                          lat,
                          lng,
                          officeLat: officeLat,
                          officeLng: officeLng,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final String verdict;
  final bool isSelected;
  final bool isReject;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.verdict,
    required this.isSelected,
    this.isReject = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? (isReject ? AppTheme.statusRejected : const Color(0xFF7C3AED))
        : const Color(0xFFCBD5E1);

    final bgColor = isSelected
        ? (isReject ? const Color(0xFFFEF2F2) : const Color(0xFFF3E8FF))
        : Colors.white;

    final textColor = isSelected
        ? (isReject ? AppTheme.statusRejected : const Color(0xFF6D28D9))
        : AppTheme.textDark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            Text(
              verdict,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isReject ? AppTheme.statusRejected : AppTheme.statusSuccess,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
