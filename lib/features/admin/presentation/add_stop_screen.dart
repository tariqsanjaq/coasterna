import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/stop_model.dart';
import '../../search/data/route_repository.dart';
import 'admin_form_widgets.dart';

/// Admin form for the `stops` collection. One panel, two modes:
///
///  * ADD mode  — StopFormPanel()                  creates a document
///  * EDIT mode — StopFormPanel(existingStop: s)    overwrites s
///
/// It is a panel, not a screen: it renders inside the Admin shell's
/// content area so the sidebar stays visible, which is how spec v8.7
/// page 19 shows the Add route form. It therefore has no Scaffold and
/// no AppBar, and reports back through [onSaved] and [onCancel]
/// instead of calling Navigator.
///
/// Layout follows the same page: labels above the fields, fields in a
/// grid, and Cancel / Save at the bottom right.
///
/// The spec has no page for a stop form. This one is built to the
/// route form's pattern — a documented, deliberate extension.
///
/// All writes go through RouteRepository; this widget never touches
/// Firestore directly.
class StopFormPanel extends StatefulWidget {
  const StopFormPanel({
    super.key,
    this.existingStop,
    required this.onSaved,
    required this.onCancel,
  });

  /// null => add a new stop. Not null => edit this stop.
  final StopModel? existingStop;

  /// Called after a successful write, so the shell can return to the
  /// list and reload it.
  final VoidCallback onSaved;

  /// Called when the admin backs out without saving.
  final VoidCallback onCancel;

  @override
  State<StopFormPanel> createState() => _StopFormPanelState();
}

class _StopFormPanelState extends State<StopFormPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  final _repository = RouteRepository();

  bool get _isEditMode => widget.existingStop != null;

  @override
  void initState() {
    super.initState();
    // In edit mode the form opens already filled, so the admin changes
    // one field instead of retyping all five.
    final stop = widget.existingStop;
    if (stop != null) {
      _nameController.text = stop.name;
      _areaController.text = stop.area;
      _latController.text = stop.latitude.toString();
      _lngController.text = stop.longitude.toString();
      _isActive = stop.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Runs every field's validator. If any returns a non-null string,
    // validate() shows it under that field and returns false — we stop
    // here rather than writing bad data to Firestore.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final stop = StopModel(
        // Add mode: toFirestore() ignores the id and Firestore assigns
        // the real one. Edit mode: the id that decides which document
        // is written is the one passed to updateStop below.
        id: widget.existingStop?.id ?? '',
        name: _nameController.text.trim(),
        area: _areaController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        isActive: _isActive,
      );

      if (_isEditMode) {
        await _repository.updateStop(widget.existingStop!.id, stop);
      } else {
        await _repository.createStop(stop);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? '"${stop.name}" updated.'
                : '"${stop.name}" saved.',
          ),
          duration: const Duration(seconds: 3),
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

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  // Jordan's rough bounding box — catches the beginner mistake of
  // typing latitude and longitude into the wrong field, which look
  // interchangeable to someone who has never plotted a coordinate.
  String? _latValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) return 'Must be a number';
    if (parsed < 29 || parsed > 33.5) {
      return 'Outside Jordan — check for a lat/lng swap';
    }
    return null;
  }

  String? _lngValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) return 'Must be a number';
    if (parsed < 34.5 || parsed > 39.5) {
      return 'Outside Jordan — check for a lat/lng swap';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: AdminFormShell(
        children: [
          AdminFormHeader(
            title: _isEditMode ? 'Edit Stop' : 'Add Stop',
            subtitle: 'Coordinates come from field-collected survey sheets.',
          ),
          const SizedBox(height: AppSpacing.md),

          // Renaming a stop does not rewrite the copies of its name
          // already stored on route documents, so the admin has to be
          // told or the data drifts silently.
          if (_isEditMode) ...[
            const AdminNoticeBanner(
              text: 'Changing the Name does not rename this stop on routes '
                  'that already use it. Update those routes as well, or '
                  'their cards will keep showing the old name.',
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          AdminFormRow(
            columns: 2,
            children: [
              AdminLabeledField(
                label: 'Name',
                child: TextFormField(
                  controller: _nameController,
                  decoration: adminInputDecoration(
                    hintText: 'Sweileh Bus Terminal',
                  ),
                  validator: _requiredValidator,
                ),
              ),
              AdminLabeledField(
                label: 'Area',
                child: TextFormField(
                  controller: _areaController,
                  decoration: adminInputDecoration(hintText: 'Amman'),
                  validator: _requiredValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AdminFormRow(
            columns: 2,
            children: [
              AdminLabeledField(
                label: 'Latitude',
                child: TextFormField(
                  controller: _latController,
                  decoration: adminInputDecoration(hintText: '32.0289'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _latValidator,
                ),
              ),
              AdminLabeledField(
                label: 'Longitude',
                child: TextFormField(
                  controller: _lngController,
                  decoration: adminInputDecoration(hintText: '35.8342'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: _lngValidator,
                ),
              ),
            ],
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
            saveLabel: _isEditMode ? 'Update Stop' : 'Save Stop',
            isSaving: _isSaving,
          ),
        ],
      ),
    );
  }
}