import 'dart:async';
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
///
/// Reads its favorited state from `FavoritesRepository.idsNotifier`
/// on every build rather than caching it locally, so every instance
/// for the same `routeId` — a search card and the Trip Details AppBar
/// star, say — repaints the moment any one of them toggles it.
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

  @override
  void initState() {
    super.initState();
    // Kicks off the load for the current user's favorites if it
    // hasn't happened yet; the ValueListenableBuilder below repaints
    // once idsNotifier is populated. Concurrent instances share one
    // in-flight load (see FavoritesRepository._ensureLoaded).
    unawaited(_repository.getFavoriteRouteIds());
  }

  Future<void> _toggle() async {
    final nowFavorite = await _repository.toggleFavorite(widget.routeId);
    if (!mounted) return;
    widget.onChanged?.call(nowFavorite);
  }

  @override
  Widget build(BuildContext context) {
    // The icon change itself is the feedback — no snackbar needed.
    return ValueListenableBuilder<Set<String>>(
      valueListenable: FavoritesRepository.idsNotifier,
      builder: (context, favoriteIds, _) {
        final isFavorite = favoriteIds.contains(widget.routeId);
        return IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? AppColors.accent : AppColors.textTertiary,
          ),
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: _toggle,
        );
      },
    );
  }
}
