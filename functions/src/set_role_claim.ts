/**
 * Firebase Blocking Function: beforeSignIn
 *
 * Adds role: "authenticated" to the Firebase ID token custom claims before
 * it is issued. This satisfies Supabase Third-Party Auth which requires the
 * JWT to carry role: "authenticated" for RLS policies to recognise the user
 * as authenticated.
 *
 * Requires: Identity Platform (Firebase Auth with Identity Platform upgrade).
 * Deploy: firebase deploy --only functions:beforeSignIn --project viva-analytics-135d4
 *
 * NOTE: Credentials for deployment come from `firebase login` — never stored
 * in source code or the repository.
 */
import { auth } from "firebase-functions/v2";

export const beforeSignIn = auth.user().beforeSignIn((user, context) => {
  // Add role: "authenticated" to custom claims.
  // This claim is included in every subsequent ID token for this user.
  // Supabase Third-Party Auth reads it to set the Postgres role.
  return {
    customClaims: {
      role: "authenticated",
    },
  };
});
