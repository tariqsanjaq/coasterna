import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Building blocks for the two admin forms, taken from spec v8.7
/// page 19 (Add route form): a title with an italic sub-line, a gold
/// notice banner, small upper-case labels sitting ABOVE their fields,
/// fields laid out in a grid, and a Cancel / Save pair at the bottom
/// right.
///
/// They live in their own file because the stop form and the route
/// form both need them; duplicating them would mean fixing every
/// styling change twice.

/// Gold used by the notice banner. Spec page 3 calls this Warning and
/// reserves it for the departs-when-full pill, the offline banner, and
/// notices — which is exactly what this banner is.
const Color _kWarning = Color(0xFFA66300);
const Color _kWarningBg = Color(0xFFFBF3E3);

/// Corner radius for buttons and fields. Spec page 3: cards and
/// dialogs 12px, buttons and fields 8px, chips 4px.
const double kAdminFieldRadius = 8;

/// Panel title plus the italic explanatory line beneath it.
class AdminFormHeader extends StatelessWidget {
  const AdminFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// The gold notice strip that runs the full width of the form.
class AdminNoticeBanner extends StatelessWidget {
  const AdminNoticeBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kWarningBg,
        border: Border.all(color: _kWarning.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(kAdminFieldRadius),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.45,
          color: _kWarning,
        ),
      ),
    );
  }
}

/// The small upper-case label that sits above a field.
class AdminFieldLabel extends StatelessWidget {
  const AdminFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// The shared field decoration: a visible outline, 8px corners, and
/// no floating label — the label lives above the box instead.
InputDecoration adminInputDecoration({String? hintText}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(kAdminFieldRadius)),
    borderSide: BorderSide(color: AppColors.surfaceBorder),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      fontSize: 13,
      color: AppColors.textSecondary,
    ),
    isDense: true,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(kAdminFieldRadius)),
      borderSide: BorderSide(color: AppColors.primary, width: 1.4),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(kAdminFieldRadius)),
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(kAdminFieldRadius)),
      borderSide: BorderSide(color: AppColors.error, width: 1.4),
    ),
  );
}

/// A label stacked on top of any field widget.
class AdminLabeledField extends StatelessWidget {
  const AdminLabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label),
        child,
      ],
    );
  }
}

/// One grid row. Every child takes an equal share of the width, and
/// short rows are padded with empty cells so the columns of different
/// rows still line up with each other.
class AdminFormRow extends StatelessWidget {
  const AdminFormRow({
    super.key,
    required this.children,
    this.columns = 3,
  });

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < columns; i++) {
      if (i > 0) cells.add(const SizedBox(width: AppSpacing.md));
      cells.add(
        Expanded(
          child: i < children.length ? children[i] : const SizedBox(),
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: cells,
    );
  }
}

/// Cancel and Save, aligned to the bottom right as on spec page 19.
///
/// Both buttons set minimumSize with a zero width on purpose. The app
/// theme makes every ElevatedButton full-width, which is right inside
/// a vertical form but breaks inside a Row: a Row measures a non-flex
/// child with unbounded width first, and "as wide as possible" has no
/// answer when the space is infinite.
class AdminFormActions extends StatelessWidget {
  const AdminFormActions({
    super.key,
    required this.onCancel,
    required this.onSave,
    required this.saveLabel,
    required this.isSaving,
    this.leading,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final String saveLabel;
  final bool isSaving;

  /// Optional widget shown on the left of the row — the Active toggle
  /// sits there in the approved design.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ?leading,
        const Spacer(),
        TextButton(
          onPressed: isSaving ? null : onCancel,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 48),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        ElevatedButton(
          onPressed: isSaving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kAdminFieldRadius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          ),
          child: isSaving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text(
            saveLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// The white panel the whole form sits on, with the standard padding
/// and a scroll for short windows.
class AdminFormShell extends StatelessWidget {
  const AdminFormShell({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}