/// Carries at most one guest action through a sign-in — decision D52
/// part 2. A guest taps the favorite star or "Report an issue" before
/// they have an account; the tap stores one of these, the app sends
/// them to sign in, and once sign-in succeeds the app completes the
/// stored action instead of just returning them to wherever they were.
///
/// Sealed with exactly two cases on purpose, per the decision: nothing
/// else in the app currently redirects a guest to sign in mid-action.
/// A `switch` over [PendingIntent] is exhaustively checked by the
/// compiler — adding a third case anywhere would fail to compile until
/// every switch handling one is updated.
sealed class PendingIntent {
  const PendingIntent(this.routeId, this.routeName);

  final String routeId;

  /// Denormalized copy of the route's display name, so the code that
  /// completes this intent after sign-in (and any confirmation it
  /// shows) never needs a second Firestore read just to name the
  /// route — same reasoning `ReportModel.routeName` already documents.
  final String routeName;
}

/// A guest tapped the favorite star before signing in.
class PendingFavorite extends PendingIntent {
  const PendingFavorite(super.routeId, super.routeName);
}

/// A guest tapped "Report an issue" before signing in.
class PendingReport extends PendingIntent {
  const PendingReport(super.routeId, super.routeName);
}

/// Holds at most one [PendingIntent] in memory, from the moment a
/// guest is redirected to sign in until sign-in completes.
///
/// In-memory only — this does not need to survive an app restart. A
/// pending intent that dies when the app is killed mid-sign-in is no
/// worse than the guest never having tapped the button in the first
/// place. Same "simple static holder" spirit as
/// `FavoritesRepository.idsNotifier`, minus the `ValueNotifier`:
/// nothing needs to be notified when a pending intent changes, only
/// the sign-in/sign-up screens read it, exactly once, right after
/// navigating home.
class PendingIntentHolder {
  PendingIntentHolder._();

  static PendingIntent? _pending;

  /// Overwrites whatever was pending, if anything — only one intent is
  /// ever tracked at a time (decision D52 part 2). A guest who taps
  /// the favorite star, backs out, then taps "Report an issue" on a
  /// different route is not a scenario worth juggling two intents for;
  /// the most recent tap wins.
  static void set(PendingIntent intent) {
    _pending = intent;
  }

  /// Returns the pending intent, if any, and clears it in the same
  /// call so it can never be consumed twice.
  static PendingIntent? consume() {
    final intent = _pending;
    _pending = null;
    return intent;
  }
}
