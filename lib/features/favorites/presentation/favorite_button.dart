import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/favorites_repository.dart';

/// Star toggle for one route's favorite status.
///
/// ASSUMES the caller has already checked that a student is signed
/// in — this widget does not check `AuthRepository().currentUser`
/// itself. Favoriting is device-local and has no concept of "whose"
/// favorite it is, so nothing here would actually break for a guest;
/// the auth gate exists purely so guests are not shown a feature that
/// implies an account. Every call site is expected to wrap this
/// widget in `if (_authRepository.currentUser != null) ...` the same
/// way the sign-out icon in home_page.dart is gated.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.routeId, this.onChanged});

  final String routeId;

  /// Called after a successful toggle with the new favorited state.
  /// Optional — most call sites don't need it. FavoritesScreen uses it
  /// to remove a card from its own list the moment it is unfavorited,
  /// without waiting for a full reload.
  final ValueChanged<bool>? onChanged;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _repository = FavoritesRepository();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final isFavorite = await _repository.isFavorite(widget.routeId);
    if (!mounted) return;
    setState(() => _isFavorite = isFavorite);
  }

  Future<void> _toggle() async {
    await _repository.toggleFavorite(widget.routeId);
    if (!mounted) return;
    final newValue = !_isFavorite;
    setState(() => _isFavorite = newValue);
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    // The icon change itself is the feedback — no snackbar needed.
    return IconButton(
      icon: Icon(
        _isFavorite ? Icons.star : Icons.star_border,
        color: _isFavorite ? AppColors.accent : AppColors.textTertiary,
      ),
      tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
      onPressed: _toggle,
    );
  }
}
