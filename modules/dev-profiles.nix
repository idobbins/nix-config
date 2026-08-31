{ config, lib, ... }:

let
  cfg = config.devProfiles;
  profileType = lib.types.submodule {
    options = {
      requiredVariables = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Environment variables that the resolved 1Password profile must provide.";
      };

      secretReferences = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables mapped to op:// secret references.";
      };
    };
  };

  requiredFiles = lib.mapAttrs' (
    name: profile:
    lib.nameValuePair "dev-profiles/${name}.required" {
      text = lib.concatMapStringsSep "\n" (variable: variable) profile.requiredVariables + "\n";
    }
  ) cfg;

  referenceFiles = lib.mapAttrs' (
    name: profile:
    lib.nameValuePair "dev-profiles/${name}.env.op" {
      text =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            variable: reference: "${variable}=${builtins.toJSON reference}"
          ) profile.secretReferences
        )
        + "\n";
    }
  ) (lib.filterAttrs (_name: profile: profile.secretReferences != { }) cfg);
in
{
  options.devProfiles = lib.mkOption {
    type = lib.types.attrsOf profileType;
    default = { };
    description = "Named, directory-activated development credential profiles.";
  };

  config = lib.mkIf (cfg != { }) {
    xdg.configFile = requiredFiles // referenceFiles;

    programs.direnv.stdlib = lib.mkAfter ''
      # Resolve a named file of op:// references into the current direnv.
      # Secret values are fetched at runtime and never evaluated by Nix.
      use_op_profile() {
        local profile="''${1-}"
        local config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        local references="$config_home/dev-profiles/$profile.env.op"
        local required="$config_home/dev-profiles/$profile.required"

        if [[ -z "$profile" ]]; then
          log_error "use_op_profile requires a profile name"
          return 1
        fi
        if [[ ! -r "$required" ]]; then
          log_error "unknown development profile: $profile"
          return 1
        fi
        if [[ ! -r "$references" ]]; then
          log_error "missing 1Password references: $references"
          log_error "create it as a dotenv file whose values are op:// references"
          return 1
        fi
        if ! command -v op >/dev/null 2>&1; then
          log_error "1Password CLI (op) is not available"
          return 1
        fi

        watch_file "$references" "$required"

        # direnv_load imports the environment emitted by the child direnv.
        # Masking must be disabled for this machine-readable, captured output.
        direnv_load op run --no-masking --env-file "$references" -- direnv dump || return

        local variable
        while IFS= read -r variable; do
          [[ -z "$variable" ]] && continue
          if [[ -z "''${!variable+x}" ]]; then
            log_error "1Password profile $profile did not provide $variable"
            return 1
          fi
        done < "$required"
      }
    '';
  };
}
