import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/core_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/clock.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/leave/presentation/screens/leave_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/sync/presentation/providers/sync_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database for company timezone calculations
  Clock.ensureTimezoneInitialized();

  // Load persistent preferences for runtime URL overrides
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const RebsHrmsApp(),
    ),
  );
}

class RebsHrmsApp extends StatelessWidget {
  const RebsHrmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'REBS HRMS',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const AppShell(),
    );
  }
}

/// Root application shell providing bottom navigation across
/// Dashboard, Leaves, and Settings tabs with IndexedStack state preservation.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = ref.watch(syncNotifierProvider);

    final screens = [
      DashboardScreen(
        onNavigateToLeave: () => _onDestinationSelected(1),
      ),
      const LeaveScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          NavigationDestination(
            icon: syncState.pendingCount > 0
                ? Badge(
                    label: Text('${syncState.pendingCount}'),
                    child: const Icon(Icons.dashboard_outlined),
                  )
                : const Icon(Icons.dashboard_outlined),
            selectedIcon: syncState.pendingCount > 0
                ? Badge(
                    label: Text('${syncState.pendingCount}'),
                    child: const Icon(Icons.dashboard),
                  )
                : const Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Leaves',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
