import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/pending_intent.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/student_login_screen.dart';
import '../data/favorites_repository.dart';

/// Star toggle for one route's favorite status.
///
/// SHOWN TO EVERYONE, signed in or not (decision D52 part 2) — call
/// sites no longer need to gate this behind
/// `_authRepository.currentUser != null`. A signed-in tap toggles the
/// favorite immediately, same as before. A guest tap stores a
/// [PendingFavorite] via [PendingIntentHolder] and sends the student to
/// `StudentLoginScreen` instead of toggling anything; once they sign
/// in, `pending_intent_completion.dart` finishes the toggle for them
/// and shows a confirmation.
///
/// Reads its favorited state from `FavoritesRepository.idsNotifier`
/// on every build rather than caching it locally, so every instance
/// for the same `routeId` — a search card and the Trip Details AppBar
/// star, say — repaints the moment any one of them toggles it.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.routeId,
    required this.routeName,
    this.onChanged,
  });

  final String routeId;

  /// Denormalized route display name, only actually used on a guest
  /// tap — carried into the [PendingFavorite] so the post-sign-in
  /// confirmation flow never needs a second Firestore read just to
  /// know which route this button was for.
  final String routeName;

  /// Called after a successful toggle with the new favorited state.
  /// Optional — most call sites don't need it. FavoritesScreen uses it
  /// to remove a card from its own list the moment it is unfavorited,
  /// without waiting for a full reload. Not called on a guest tap —
  /// there is nothing to toggle yet.
  final ValueChanged<bool>? onChanged;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _repository = FavoritesRepository();
  final _authRepository = AuthRepository();

  @override
  void initState() {
    super.initState();
    // Kicks off the load for the current user's favorites if it
    // hasn't happened yet; the ValueListenableBuilder below repaints
    // once idsNotifier is populated. Concurrent instances share one
    // in-flight load (see FavoritesRepository._ensureLoaded). Harmless
    // for a guest too — FavoritesRepository already falls back to a
    // `_guest` storage key when nobody is signed in.
    unawaited(_repository.getFavoriteRouteIds());
  }

  void _handleTap() {
    if (_authRepository.currentUser == null) {
      PendingIntentHolder.set(
        PendingFavorite(widget.routeId, widget.routeName),
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StudentLoginScreen()),
      );
      return;
    }
    unawaited(_toggle());
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
          onPressed: _handleTap,
        );
      },
    );
  }
}
