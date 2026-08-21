import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/stop_model.dart';
import '../../search/data/route_repository.dart';
import 'admin_form_widgets.dart';

/// Admin form for one document in the `routes` collection, built to
/// spec v8.7 page 19.
///
/// It is a panel, not a screen: it renders inside the Admin shell so
/// the sidebar stays visible, and reports back through [onSaved] and
/// [onCancel] instead of calling Navigator.
///
/// One widget serves both add and edit. Pass [existingRoute] to edit;
/// leave it null to add. The alternative — a second near-identical
/// form — is how two forms drift apart until one of them writes a
/// field the other does not.
///
/// Origin and destination are picked from real Stop documents already
/// in Firestore. Waypoints in between are free-form names used only by
/// the trip-details timeline — they are not searchable (decision log,
/// Aug 2026).
///
/// COLLECTED BY and COLLECTED ON are entered by hand. They used to be
/// hard-coded, which credited every route to one person and recorded
/// the date it was typed rather than the date it was surveyed. Both
/// feed the data-provenance table in the report, so they have to be
/// true.
class RouteFormPanel extends StatefulWidget {
  const RouteFormPanel({
    super.key,
    required this.onSaved,
    required this.onCancel,
    this.existingRoute,
  });

  final VoidCallback onSaved;
  final VoidCallback onCancel;

  /// The route being edited, or null when adding a new one.
  final RouteModel? existingRoute;

  @override
  State<RouteFormPanel> createState() => _RouteFormPanelState();
}

class _RouteFormPanelState extends State<RouteFormPanel> {
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
  final _collectedByController = TextEditingController();
  final _collectedOnController = TextEditingController();

  List<StopModel> _stops = [];
  bool _isLoadingStops = true;
  bool _loadFailed = false;
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

  bool get _isEditing => widget.existingRoute != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingRoute;
    if (existing != null) {
      _routeNameController.text = existing.routeName;
      _operatorController.text = existing.operatorName;
      _priceController.text = existing.priceJD.toStringAsFixed(2);
      _durationController.text = existing.durationMinutes.toString();
      _firstDepController.text = existing.firstDeparture;
      _lastDepController.text = existing.lastDeparture;
      _frequencyController.text = existing.frequencyMinutes?.toString() ?? '';
      _collectedByController.text = existing.collectedBy;
      _collectedOnController.text = _formatDate(existing.collectedOn);

      _direction = existing.direction;
      _departureType = existing.departureType;
      _isActive = existing.isActive;

      _selectedDays
        ..clear()
        ..addAll(existing.operatingDays);

      _waypoints.addAll(_waypointNamesFrom(existing.stops));
    } else {
      // Default the survey date to today. It stays editable, because a
      // route is often entered days after it was actually recorded.
      _collectedOnController.text = _formatDate(DateTime.now());
    }

    _loadStops();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _formatDate(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  /// Pulls the editable middle out of a saved `stops` array.
  ///
  /// The array is flat: origin at order 0, the waypoints in between,
  /// destination last. Origin and destination are not editable here —
  /// they come from the two dropdowns — so only the middle is handed
  /// to the waypoint list. Sorting by `order` first rather than
  /// trusting the stored array order means a document written by hand
  /// in the Firebase Console still opens in the right sequence.
  static List<String> _waypointNamesFrom(List<RouteStop> stops) {
    if (stops.length <= 2) return const [];
    final ordered = [...stops]..sort((a, b) => a.order.compareTo(b.order));
    return ordered
        .sublist(1, ordered.length - 1)
        .map((stop) => stop.stopName)
        .toList();
  }

  /// Reads every stop, then narrows the list in Dart.
  ///
  /// The student-facing getAllStops() returns active stops only. Using
  /// it here would crash the form the moment an admin edited a route
  /// whose origin had since been deactivated: DropdownButtonFormField
  /// throws when its value is not among its items — "There should be
  /// exactly one item with [DropdownButton]'s value". That crash would
  /// happen on opening the panel.
  ///
  /// So the admin variant is read instead, and the list is narrowed to
  /// active stops PLUS the two this route already points at. In add
  /// mode there is no route, so the result is exactly the active stops
  /// — the old behaviour, unchanged. No extra query, no new index.
  Future<void> _loadStops() async {
    try {
      final all = await _repository.getAllStopsForAdmin();
      if (!mounted) return;

      final existing = widget.existingRoute;
      final visible = all
          .where((stop) =>
      stop.isActive ||
          stop.id == existing?.originStopId ||
          stop.id == existing?.destinationStopId)
          .toList();

      StopModel? origin;
      StopModel? destination;
      if (existing != null) {
        for (final stop in visible) {
          if (stop.id == existing.originStopId) origin = stop;
          if (stop.id == existing.destinationStopId) destination = stop;
        }
      }

      setState(() {
        _stops = visible;
        if (existing != null) {
          _origin = origin;
          _destination = destination;
        }
        _isLoadingStops = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingStops = false;
        _loadFailed = true;
      });
    }
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
    _collectedByController.dispose();
    _collectedOnController.dispose();
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

  /// Moves one waypoint up or down by a single position.
  ///
  /// The order of this list is what becomes the `order` field on each
  /// RouteStop when the route is saved, and that order is exactly what
  /// the trip timeline shows the student. Before this existed, a
  /// waypoint entered out of sequence could only be corrected by
  /// deleting it and everything after it and retyping the lot — on a
  /// route with twelve intermediate stops that is where transcription
  /// errors come from.
  ///
  /// Up and down buttons were chosen over drag-and-drop deliberately:
  /// a ReorderableListView has to be nested inside the form's own
  /// scroll view, and nesting a scrollable inside a scrollable is the
  /// same class of layout problem that once rendered this entire panel
  /// blank. Two buttons cannot fail that way.
  void _moveWaypoint(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _waypoints.length) return;
    setState(() {
      final moved = _waypoints.removeAt(index);
      _waypoints.insert(target, moved);
    });
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  /// Accepts YYYY-MM-DD only. A free-text date would end up stored in
  /// three different formats across the collection within a week.
  String? _dateValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    final parsed = DateTime.tryParse(value!.trim());
    if (parsed == null) return 'Use YYYY-MM-DD';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null || _destination == null) {
      setState(() =>
      _errorMessage = 'Pick both an origin and a destination stop.');
      return;
    }
    if (_origin!.id == _destination!.id) {
      setState(() =>
      _errorMessage = 'Origin and destination cannot be the same stop.');
      return;
    }

    // There is deliberately no guard on _selectedDays being empty.
    // An empty operatingDays array is the documented way to record
    // "this route runs every day" — see docs/data-model.md, and the
    // matching assertion in test/route_status_test.dart. Requiring at
    // least one chip made an every-day route impossible to enter and
    // forced the admin to select all seven instead, which the trip
    // screen then renders as "Sun to Sat" rather than "Every day",
    // leaving two representations of one fact in the collection.

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final existing = widget.existingRoute;

      // The array is rebuilt from scratch on every save rather than
      // patched. `order` is the list position, so a moved waypoint
      // renumbers everything after it — recomputing is both simpler
      // and impossible to get half-right.
      final stops = <RouteStop>[
        RouteStop(stopId: _origin!.id, stopName: _origin!.name, order: 0),
        for (var i = 0; i < _waypoints.length; i++)
          RouteStop(
            stopId: 'wp-${i + 1}',
            stopName: _waypoints[i],
            order: i + 1,
          ),
        RouteStop(
          stopId: _destination!.id,
          stopName: _destination!.name,
          order: _waypoints.length + 1,
        ),
      ];

      final route = RouteModel(
        id: existing?.id ?? '',
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
        collectedBy: _collectedByController.text.trim(),
        collectedOn: DateTime.parse(_collectedOnController.text.trim()),
      );

      if (existing == null) {
        await _repository.createRoute(route);
      } else {
        await _repository.updateRoute(existing.id, route);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${route.routeName}" ${existing == null ? 'saved' : 'updated'}.',
          ),
        ),
      );
      widget.onSaved();
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.error, size: 32),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Could not load stops. Check your connection.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoadingStops = true;
                  _loadFailed = false;
                });
                _loadStops();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_stops.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Text(
            'No active stops exist yet. Add at least two stops before '
                'creating a route.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: AdminFormShell(
        children: [
          AdminFormHeader(
            title: _isEditing ? 'Edit Route' : 'Add Route',
            subtitle: 'All values come from field-collected survey sheets.',
          ),
          const SizedBox(height: AppSpacing.md),
          AdminNoticeBanner(
            text: _isEditing
            // A route's identity is originStopId + destinationStopId
            // + direction. Changing either stop does not correct a
            // mistake in this route: it turns it into a different
            // route, which may already exist as its own document.
                ? 'Changing the origin or destination changes which trip '
                'this route describes. Check that no other route '
                'already covers the new pair before saving.'
                : 'Check for an existing route with the same origin and '
                'destination before saving — duplicates confuse student '
                'search results.',
          ),
          const SizedBox(height: AppSpacing.md),

          AdminFormRow(
            children: [
              AdminLabeledField(
                label: 'Operator name',
                child: TextFormField(
                  controller: _operatorController,
                  decoration: adminInputDecoration(
                    hintText: 'Al-Nasr Coaster Lines',
                  ),
                  validator: _requiredValidator,
                ),
              ),
              AdminLabeledField(
                label: 'Route name',
                child: TextFormField(
                  controller: _routeNameController,
                  decoration: adminInputDecoration(
                    hintText: 'Sweileh to AAU Main Gate',
                  ),
                  validator: _requiredValidator,
                ),
              ),
              AdminLabeledField(
                label: 'Direction',
                child: DropdownButtonFormField<RouteDirection>(
                  initialValue: _direction,
                  decoration: adminInputDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: RouteDirection.outbound,
                      child: Text('Outbound'),
                    ),
                    DropdownMenuItem(
                      value: RouteDirection.returnTrip,
                      child: Text('Return'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _direction = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          AdminFormRow(
            children: [
              AdminLabeledField(
                label: 'Origin stop',
                child: DropdownButtonFormField<StopModel>(
                  initialValue: _origin,
                  isExpanded: true,
                  decoration: adminInputDecoration(),
                  items: _stops
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ))
                      .toList(),
                  onChanged: (value) => setState(() => _origin = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
              ),
              AdminLabeledField(
                label: 'Destination stop',
                child: DropdownButtonFormField<StopModel>(
                  initialValue: _destination,
                  isExpanded: true,
                  decoration: adminInputDecoration(),
                  items: _stops
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _destination = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
              ),
              AdminLabeledField(
                label: 'Departure type',
                child: DropdownButtonFormField<DepartureType>(
                  initialValue: _departureType,
                  decoration: adminInputDecoration(),
                  items: const [
                    DropdownMenuItem(
                      value: DepartureType.whenFull,
                      child: Text('WHEN_FULL'),
                    ),
                    DropdownMenuItem(
                      value: DepartureType.scheduled,
                      child: Text('SCHEDULED'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _departureType = value!),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          AdminFormRow(
            children: [
              AdminLabeledField(
                label: 'Price in JD',
                child: TextFormField(
                  controller: _priceController,
                  decoration: adminInputDecoration(hintText: '0.55'),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) =>
                  double.tryParse(v?.trim() ?? '') == null
                      ? 'Must be a number'
                      : null,
                ),
              ),
              AdminLabeledField(
                label: 'Duration in minutes',
                child: TextFormField(
                  controller: _durationController,
                  decoration: adminInputDecoration(hintText: '35'),
                  keyboardType: TextInputType.number,
                  validator: (v) => int.tryParse(v?.trim() ?? '') == null
                      ? 'Must be a whole number'
                      : null,
                ),
              ),
              AdminLabeledField(
                label: 'First departure',
                child: TextFormField(
                  controller: _firstDepController,
                  decoration: adminInputDecoration(hintText: '06:30'),
                  validator: _requiredValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          AdminFormRow(
            children: [
              AdminLabeledField(
                label: 'Last departure',
                child: TextFormField(
                  controller: _lastDepController,
                  decoration: adminInputDecoration(hintText: '19:30'),
                  validator: _requiredValidator,
                ),
              ),
              AdminLabeledField(
                label: 'Collected by',
                child: TextFormField(
                  controller: _collectedByController,
                  decoration: adminInputDecoration(hintText: 'Tariq Sanjaq'),
                  validator: _requiredValidator,
                ),
              ),
              AdminLabeledField(
                label: 'Collected on',
                child: TextFormField(
                  controller: _collectedOnController,
                  decoration: adminInputDecoration(hintText: '2026-06-14'),
                  validator: _dateValidator,
                ),
              ),
            ],
          ),

          // Only a SCHEDULED route has a gap between buses. Asking for
          // one on a WHEN_FULL route would invite an invented number,
          // and the result card would then show a countdown no driver
          // ever promised.
          if (_departureType == DepartureType.scheduled) ...[
            const SizedBox(height: AppSpacing.md),
            AdminFormRow(
              children: [
                AdminLabeledField(
                  label: 'Frequency in minutes',
                  child: TextFormField(
                    controller: _frequencyController,
                    decoration: adminInputDecoration(hintText: '25'),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v?.trim() ?? '') == null
                        ? 'Required when SCHEDULED'
                        : null,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const AdminFieldLabel('Operating days'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _allDays.map((day) {
              final selected = _selectedDays.contains(day);
              return ChoiceChip(
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
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Leave every day unselected if the route runs all week.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          const AdminFieldLabel('Stops'),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Waypoints are saved in the order shown. Use the arrows to '
                'move one without retyping the rest.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kAdminFieldRadius),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StopLine(
                  text: _origin?.name ?? 'Origin stop (pick one above)',
                  muted: _origin == null,
                ),
                for (var i = 0; i < _waypoints.length; i++)
                  _StopLine(
                    text: _waypoints[i],
                    // Disabled at the ends. A null onPressed greys the
                    // button out, which tells the admin the move is
                    // impossible instead of doing nothing silently.
                    onMoveUp: i == 0 ? null : () => _moveWaypoint(i, -1),
                    onMoveDown: i == _waypoints.length - 1
                        ? null
                        : () => _moveWaypoint(i, 1),
                    onRemove: () => _removeWaypoint(i),
                  ),
                _StopLine(
                  text: _destination?.name ??
                      'Destination stop (pick one above)',
                  muted: _destination == null,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _waypointController,
                        decoration: adminInputDecoration(
                          hintText: 'Add a waypoint, e.g. Al-Kamaliya',
                        ),
                        onSubmitted: (_) => _addWaypoint(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      onPressed: _addWaypoint,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: const Text('+ Add stop'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          AdminFormActions(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _isActive,
                  activeThumbColor: AppColors.accent,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text('Active'),
              ],
            ),
            onCancel: widget.onCancel,
            onSave: _save,
            saveLabel: _isEditing ? 'Save changes' : 'Save Route',
            isSaving: _isSaving,
          ),
        ],
      ),
    );
  }
}

/// One line in the ordered stops box.
///
/// Origin and destination come from the dropdowns and carry no
/// buttons: they are fixed by definition, and the first and last
/// entries of the saved `stops` array. Only waypoints can be moved or
/// removed, which is why every button is gated on [onRemove] being
/// supplied.
class _StopLine extends StatelessWidget {
  const _StopLine({
    required this.text,
    this.onRemove,
    this.onMoveUp,
    this.onMoveDown,
    this.muted = false,
  });

  final String text;
  final VoidCallback? onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                color: muted
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (onRemove != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 16),
              color: AppColors.textSecondary,
              tooltip: 'Move up',
              onPressed: onMoveUp,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 16),
              color: AppColors.textSecondary,
              tooltip: 'Move down',
              onPressed: onMoveDown,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.error,
              tooltip: 'Remove waypoint',
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}
