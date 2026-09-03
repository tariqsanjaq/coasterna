import 'package:flutter/material.dart';
import '../../../core/pending_intent.dart';
import '../../favorites/data/favorites_repository.dart';

/// Completes whatever a guest was trying to do before being sent to
/// sign in — decision D52 part 2. Called from both
/// `student_login_screen.dart`'s `_goToHome()` and
/// `student_signup_screen.dart`'s equivalent success path, right after
/// each one's `pushAndRemoveUntil` to Home. A no-op when nothing is
/// pending — a normal sign-in, not one that started from a guest tap.
///
/// Shared rather than duplicated in both screens: the two success
/// paths need the exact same handling here, and copying this
/// try/catch-plus-switch logic into both files would be the kind of
/// duplication that drifts the moment one of them changes.
///
/// Takes [context] from the CALLING screen (login or signup), not
/// Home's. `ScaffoldMessenger` sits above the `Navigator` in the
/// widget tree in this app's standard `MaterialApp` setup, so a
/// SnackBar shown from the old screen's context still surfaces over
/// Home once the `pushAndRemoveUntil` transition finishes — no need to
/// thread anything through to `HomePage` itself. Callers are expected
/// to fire this with `unawaited(...)` immediately after their
/// navigation call, matching the fire-and-forget pattern
/// `FavoriteButton` already uses for its own initial load.
///
/// PendingReport is NOT completed automatically. Submitting a report
/// needs the reason the student typed, which was never captured before
/// they were sent to sign in — and reopening the report form
/// automatically would mean navigating to one specific route's Trip
/// Details screen from Home, which is exactly the "return to a
/// specific prior screen" problem the pushAndRemoveUntil fix (commit
/// 1c64f98) deliberately avoids. So this only tells the student to
/// open the route again themselves.
Future<void> completePendingIntent(BuildContext context) async {
  final intent = PendingIntentHolder.consume();
  if (intent == null) return;

  switch (intent) {
    case PendingFavorite():
      try {
        await FavoritesRepository().toggleFavorite(intent.routeId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites.')),
        );
      } catch (_) {
        // Stale/deleted route, or the write failed for any other
        // reason — skip the confirmation silently rather than surface
        // an error for something the student did not explicitly
        // retry. Same "don't crash on a bad reference" spirit as
        // _useRecentSearch in home_page.dart.
      }
    case PendingReport():
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Signed in. Open the route again to finish your report.',
          ),
        ),
      );
  }
}
