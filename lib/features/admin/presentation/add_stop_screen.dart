import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/stop_model.dart';
import '../../search/data/route_repository.dart';

/// Admin form to create one new document in the `stops` collection.
/// Writes go through RouteRepository.createStop — this widget never
/// calls Firestore directly (same rule as every other screen).
class AddStopScreen extends StatefulWidget {
  const AddStopScreen({super.key});

  @override
  State createState() => _AddStopScreenState();
}

class _AddStopScreenState extends State {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;
  String? _errorMessage;

  final _repository = RouteRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future _save() async {
    // Runs every field's validator (below). If any returns a non-null
    // string, validate() shows it under that field and returns false —
    // we stop here instead of writing bad data to Firestore.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final stop = StopModel(
        id: '', // ignored by toFirestore() — Firestore assigns the real id
        name: _nameController.text.trim(),
        area: _areaController.text.trim(),
        latitude: double.parse(_latController.text.trim()),
        longitude: double.parse(_lngController.text.trim()),
        isActive: _isActive,
      );
      final newId = await _repository.createStop(stop);

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stop saved. Document ID: $newId')),
      );
      // Clear the form so a second stop can be entered right away —
      // exactly the workflow this screen exists for (Task #3 data).
      _formKey.currentState!.reset();
      _nameController.clear();
      _areaController.clear();
      _latController.clear();
      _lngController.clear();
      setState(() => _isActive = true);
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
  // typing latitude and longitude into the wrong field (they look
  // interchangeable to someone who has never plotted a coordinate).
  String? _latValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) return 'Must be a number';
    if (parsed < 29 || parsed > 33.5) {
      return 'Outside Jordan\'s latitude range — check for a lng/lat swap';
    }
    return null;
  }

  String? _lngValidator(String? value) {
    final required = _requiredValidator(value);
    if (required != null) return required;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null) return 'Must be a number';
    if (parsed < 34.5 || parsed > 39.5) {
      return 'Outside Jordan\'s longitude range — check for a lng/lat swap';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Stop'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _areaController,
                    decoration: const InputDecoration(labelText: 'Area'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _latController,
                    decoration:
                    const InputDecoration(labelText: 'Latitude'),
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: _latValidator,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _lngController,
                    decoration:
                    const InputDecoration(labelText: 'Longitude'),
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: _lngValidator,
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
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
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
                          : const Text('Save Stop'),
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