import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/location_simulator.dart';
import '../../../../core/theme/app_theme.dart';

/// Visual banner clearly indicating that simulated GPS coordinates are active.
/// SECURITY: Rendered exclusively in debug builds ([kDebugMode]).
class LocationSimulatorBanner extends ConsumerWidget {
  final VoidCallback? onConfigureTap;

  const LocationSimulatorBanner({
    super.key,
    this.onConfigureTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isLocationSimulatorAllowed) {
      return const SizedBox.shrink();
    }

    final simState = ref.watch(locationSimulatorProvider);

    if (!simState.isEnabled) {
      return const SizedBox.shrink();
    }

    final dist = simState.calculatedDistanceMeters ?? 0.0;
    final isWithin = dist <= 200.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.gps_fixed,
            color: Color(0xFF7C3AED),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'SIMULATED GPS: ${simState.activePreset.label}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B21B6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isWithin
                            ? AppTheme.statusSuccess.withValues(alpha: 0.15)
                            : AppTheme.statusRejected.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isWithin ? 'IN 200m' : 'OUT >200m',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isWithin ? AppTheme.statusSuccess : AppTheme.statusRejected,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Dist: ~${dist.toStringAsFixed(0)}m (${simState.simulatedLatitude?.toStringAsFixed(5)}, ${simState.simulatedLongitude?.toStringAsFixed(5)})',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6D28D9),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(locationSimulatorProvider.notifier).disable();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(40, 30),
            ),
            child: const Text('Real GPS', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
