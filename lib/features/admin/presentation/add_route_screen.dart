import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../search/data/route_repository.dart';

/// Admin form to create one new document in the `routes` collection.
/// Origin and destination are picked from real Stop documents already
/// in Firestore. Waypoints in between are free-form names for the
/// trip-details timeline only — not searchable (decision log, Aug 2026).
class AddRouteScreen extends StatefulWidget {
  const AddRouteScreen({super.key});

  @override
  State<AddRouteScreen> createState() => _AddRouteScreenState();
}

class _AddRouteScreenState extends State<AddRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = RouteRepository();

  final _routeNameController = TextEditingController();
  final _operatorController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _firstDepController = TextEditingController();
  final _lastDepController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _waypointController = TextEditingController();

  List<StopModel> _stops = [];
  bool _isLoadingStops = true;
  StopModel? _origin;
  StopModel? _destination;
  RouteDirection _direction = RouteDirection.outbound;
  DepartureType _departureType = DepartureType.whenFull;
  final List<String> _selectedDays = ['SUN', 'MON', 'TUE', 'WED', 'THU'];
  final List<String> _waypoints = [];
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  static const _allDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    final stops = await _repository.getAllStops();
    if (!mounted) return;
    setState(() {
      _stops = stops;
      _isLoadingStops = false;
    });
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _operatorController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _firstDepController.dispose();
    _lastDepController.dispose();
    _frequencyController.dispose();
    _waypointController.dispose();
    super.dispose();
  }

  void _addWaypoint() {
    final name = _waypointController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _waypoints.add(name);
      _waypointController.clear();
    });
  }

  void _removeWaypoint(int index) {
    setState(() => _waypoints.removeAt(index));
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null || _destination == null) {
      setState(() => _errorMessage = 'Pick both an origin and a destination stop.');
      return;
    }
    if (_origin!.id == _destination!.id) {
      setState(() => _errorMessage = 'Origin and destination cannot be the same stop.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final stops = <RouteStop>[
        RouteStop(stopId: _origin!.id, stopName: _origin!.name, order: 0),
        for (var i = 0; i < _waypoints.length; i++)
          RouteStop(stopId: 'wp-${i + 1}', stopName: _waypoints[i], order: i + 1),
        RouteStop(
          stopId: _destination!.id,
          stopName: _destination!.name,
          order: _waypoints.length + 1,
        ),
      ];

      final route = RouteModel(
        id: '',
        routeName: _routeNameController.text.trim(),
        operatorName: _operatorController.text.trim(),
        direction: _direction,
        originStopId: _origin!.id,
        originStopName: _origin!.name,
        destinationStopId: _destination!.id,
        destinationStopName: _destination!.name,
        priceJD: double.parse(_priceController.text.trim()),
        durationMinutes: int.parse(_durationController.text.trim()),
        departureType: _departureType,
        firstDeparture: _firstDepController.text.trim(),
        lastDeparture: _lastDepController.text.trim(),
        frequencyMinutes: _departureType == DepartureType.scheduled
            ? int.tryParse(_frequencyController.text.trim())
            : null,
        operatingDays: List<String>.from(_selectedDays),
        stops: stops,
        isActive: _isActive,
        collectedBy: 'Tariq Sanjaq',
        collectedOn: DateTime.now(),
      );

      final newId = await _repository.createRoute(route);

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route saved. Document ID: $newId')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStops) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_stops.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Add Route')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No stops exist yet. Go back and add at least two stops '
                  '(e.g. Mahes Terminal) before creating a route.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Route'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _routeNameController,
                    decoration: const InputDecoration(labelText: 'Route name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _operatorController,
                    decoration: const InputDecoration(labelText: 'Operator name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<StopModel>(
                    value: _origin,
                    decoration: const InputDecoration(labelText: 'Origin stop'),
                    items: _stops
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _origin = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<StopModel>(
                    value: _destination,
                    decoration: const InputDecoration(labelText: 'Destination stop'),
                    items: _stops
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _destination = value),
                    validator: (value) => value == null ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Timeline waypoints (display only, in order)',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _waypointController,
                          decoration: const InputDecoration(
                              labelText: 'e.g. Al-Kamaliya Roundabout'),
                        ),
                      ),
                      IconButton(
                        onPressed: _addWaypoint,
                        icon: const Icon(Icons.add_circle, color: AppColors.primary),
                      ),
                    ],
                  ),
                  for (var i = 0; i < _waypoints.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Text('${i + 1}.'),
                      title: Text(_waypoints[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _removeWaypoint(i),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(labelText: 'Price (JD)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) =>
                    double.tryParse(v?.trim() ?? '') == null ? 'Must be a number' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                    int.tryParse(v?.trim() ?? '') == null ? 'Must be a whole number' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<RouteDirection>(
                    value: _direction,
                    decoration: const InputDecoration(labelText: 'Direction'),
                    items: const [
                      DropdownMenuItem(
                          value: RouteDirection.outbound,
                          child: Text('OUTBOUND (towards AAU)')),
                      DropdownMenuItem(
                          value: RouteDirection.returnTrip,
                          child: Text('RETURN (away from AAU)')),
                    ],
                    onChanged: (value) => setState(() => _direction = value!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<DepartureType>(
                    value: _departureType,
                    decoration: const InputDecoration(labelText: 'Departure type'),
                    items: const [
                      DropdownMenuItem(value: DepartureType.whenFull, child: Text('WHEN_FULL')),
                      DropdownMenuItem(value: DepartureType.scheduled, child: Text('SCHEDULED')),
                    ],
                    onChanged: (value) => setState(() => _departureType = value!),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _firstDepController,
                    decoration:
                    const InputDecoration(labelText: 'First departure (e.g. 06:30)'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _lastDepController,
                    decoration: const InputDecoration(labelText: 'Last departure (e.g. 19:30)'),
                    validator: _requiredValidator,
                  ),
                  if (_departureType == DepartureType.scheduled) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _frequencyController,
                      decoration: const InputDecoration(
                          labelText: 'Frequency (minutes between buses)'),
                      keyboardType: TextInputType.number,
                      validator: (v) => int.tryParse(v?.trim() ?? '') == null
                          ? 'Required when SCHEDULED'
                          : null,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child:
                    Text('Operating days', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Wrap(
                    spacing: 8,
                    children: _allDays.map((day) {
                      final selected = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(day),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedDays.add(day);
                            } else {
                              _selectedDays.remove(day);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(_errorMessage!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: kMinTouchTarget,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Text('Save Route'),
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
}