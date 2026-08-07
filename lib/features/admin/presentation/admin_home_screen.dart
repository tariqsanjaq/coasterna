import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'add_stop_screen.dart';
import 'add_route_screen.dart';
import 'admin_manage_screen.dart';

/// Landing screen after a successful admin sign-in. Three actions:
/// add a stop, add a route, or manage (view + activate/deactivate)
/// everything that already exists.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coasterna Admin'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: kMinTouchTarget,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddStopScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Add Stop'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: kMinTouchTarget,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddRouteScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.route_outlined),
                    label: const Text('Add Route'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: kMinTouchTarget,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AdminManageScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt_outlined),
                    label: const Text('Manage Stops & Routes'),
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