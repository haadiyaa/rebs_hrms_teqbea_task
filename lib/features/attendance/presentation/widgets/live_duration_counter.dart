import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/attendance_record.dart';

/// Real-time live working duration counter widget.
/// When an employee is checked in, this timer updates every second showing HH:mm:ss.
class LiveDurationCounter extends StatefulWidget {
  final AttendanceRecord? record;

  const LiveDurationCounter({super.key, required this.record});

  @override
  State<LiveDurationCounter> createState() => _LiveDurationCounterState();
}

class _LiveDurationCounterState extends State<LiveDurationCounter> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant LiveDurationCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record != widget.record) {
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTimerIfNeeded() {
    _ticker?.cancel();
    final rec = widget.record;

    if (rec == null || rec.checkIn == null) {
      setState(() {
        _elapsed = Duration.zero;
      });
      return;
    }

    if (rec.checkOut != null) {
      // Completed session
      setState(() {
        _elapsed = rec.completedWorkingDuration ?? Duration.zero;
      });
      return;
    }

    // Active session: tick live every 1 second
    _updateLiveElapsed();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateLiveElapsed();
      }
    });
  }

  void _updateLiveElapsed() {
    final rec = widget.record;
    if (rec != null && rec.checkIn != null) {
      final now = DateTime.now();
      setState(() {
        _elapsed = rec.getLiveWorkingDuration(now) ?? Duration.zero;
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool isLive = widget.record?.checkIn != null && widget.record?.checkOut == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLive) ...[
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.statusSuccess,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              isLive ? 'LIVE WORKING DURATION' : 'TOTAL WORKING DURATION',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDuration(_elapsed),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: isLive ? AppTheme.primaryBlue : AppTheme.textDark,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
