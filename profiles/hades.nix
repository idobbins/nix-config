{ ... }:

{
  # Hades pulls shared development secrets from Vercel, then creates an
  # account-linked local Convex deployment so the project's dev defaults are
  # imported. The credentials are resolved by direnv at runtime, not by Nix.
  devProfiles.hades = {
    # Share one approval across direnv evaluations for 30 minutes. The resolved
    # values live only in the user's mode-0600 XDG cache, never in the Nix store.
    cacheTtlSeconds = 30 * 60;

    requiredVariables = [
      "CONVEX_OVERRIDE_ACCESS_TOKEN"
      "VERCEL_TOKEN"
    ];
    secretReferences = {
      CONVEX_OVERRIDE_ACCESS_TOKEN = "op://Personal/j25l3k4w3q7lccvgxrcve2fsy4/credential";
      VERCEL_TOKEN = "op://Personal/sof7237wwcyucibevnld5sm5mu/credential";
    };
  };
}
