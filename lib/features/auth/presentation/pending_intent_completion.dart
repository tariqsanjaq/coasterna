import 'package:flutter/material.dart';
import '../../../core/pending_intent.dart';
import '../data/auth_repository.dart';
import '../../favorites/data/favorites_repository.dart';

/// Completes whatever a guest was trying to do before being sent to
/// sign in — decision D52 part 2. Called from `HomePage`'s own
/// `initState` (via a post-frame callback, once the `pushAndRemoveUntil`
/// transition from `student_login_screen.dart` or
/// `student_signup_screen.dart` has actually landed on Home) rather
/// than from either sign-in screen. A no-op when nothing is pending —
/// a normal sign-in, not one that started from a guest tap.
///
/// Deliberately NOT called from the old login/signup screen's context
/// right before `pushAndRemoveUntil`, even though that used to work —
/// this app has exactly one app-wide `ScaffoldMessenger` (the implicit
/// one `MaterialApp` provides above the single `Navigator`), so a
/// SnackBar queued on it is not scoped to any particular screen or
/// route. Firing it from a screen that's mid-teardown meant the
/// confirmation kept floating over whatever screen the student
/// navigated to next — Home, Trip Details, even back at Sign In —
/// for the rest of its duration. Firing it from Home's own context,
/// after Home has actually finished mounting, ties it to the screen
/// the student actually lands on instead.
///
/// Shared rather than duplicated: both success paths need the exact
/// same handling here, and copying this try/catch-plus-switch logic
/// would be the kind of duplication that drifts the moment one of them
/// changes. Callers are expected to fire this with `unawaited(...)`,
/// matching the fire-and-forget pattern `FavoriteButton` already uses
/// for its own initial load.
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

  // A pending intent only makes sense after a REAL sign-in — "Continue
  // without signing in" reuses this exact same post-navigation path
  // (see student_login_screen.dart's _goToHome doc comment) with no
  // account ever created. `consume()` above has already discarded the
  // intent either way, so it can never linger to fire on some later,
  // legitimate sign-in — this just has to make sure a guest never gets
  // a favorite silently written under the guest key, or a false
  // confirmation for it.
  //
  // Fails CLOSED, same spirit as AuthRepository.isCurrentUserAdmin():
  // if reading currentUser throws for any reason (concretely, Firebase
  // not yet initialized — see FavoritesRepository._storageKey's own
  // doc comment for why that getter guards the identical call the same
  // way), treat it as "not signed in" rather than let the exception
  // propagate out of this fire-and-forget call.
  bool isSignedIn;
  try {
    isSignedIn = AuthRepository().currentUser != null;
  } catch (_) {
    isSignedIn = false;
  }
  if (!isSignedIn) return;

  switch (intent) {
    case PendingFavorite():
      try {
        await FavoritesRepository().toggleFavorite(intent.routeId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites.'),
            duration: Duration(seconds: 3),
          ),
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
          duration: Duration(seconds: 3),
        ),
      );
  }
}
