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

      cacheTtlSeconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = ''
          How long to reuse a user-only cache of this profile's resolved
          secrets. Zero keeps the existing in-memory-only behavior.
        '';
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

  cacheTtlFiles = lib.mapAttrs' (
    name: profile:
    lib.nameValuePair "dev-profiles/${name}.cache-ttl" {
      text = toString profile.cacheTtlSeconds + "\n";
    }
  ) cfg;
in
{
  options.devProfiles = lib.mkOption {
    type = lib.types.attrsOf profileType;
    default = { };
    description = "Named, directory-activated development credential profiles.";
  };

  config = lib.mkIf (cfg != { }) {
    xdg.configFile = requiredFiles // referenceFiles // cacheTtlFiles;

    programs.direnv.stdlib = lib.mkAfter ''
      # Resolve a named file of op:// references into the current direnv.
      # Secret values are fetched at runtime and never evaluated by Nix.
      use_op_profile() {
        local profile="''${1-}"
        local config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
        local references="$config_home/dev-profiles/$profile.env.op"
        local required="$config_home/dev-profiles/$profile.required"
        local cache_ttl_file="$config_home/dev-profiles/$profile.cache-ttl"

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
        if [[ ! -r "$cache_ttl_file" ]]; then
          log_error "missing cache policy: $cache_ttl_file"
          return 1
        fi
        if ! command -v op >/dev/null 2>&1; then
          log_error "1Password CLI (op) is not available"
          return 1
        fi

        watch_file "$references" "$required" "$cache_ttl_file"

        local cache_ttl
        IFS= read -r cache_ttl < "$cache_ttl_file"
        if [[ ! "$cache_ttl" =~ ^[0-9]+$ ]]; then
          log_error "invalid 1Password cache TTL for profile $profile"
          return 1
        fi

        if (( cache_ttl == 0 )); then
          # direnv_load imports the environment emitted by the child direnv.
          # Masking must be disabled for this machine-readable, captured output.
          direnv_load op run --no-masking --env-file "$references" -- direnv dump || return
        else
          local cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/dev-profiles"
          local cache="$cache_root/$profile.env"
          local cache_metadata="$cache.meta"
          local signature
          signature="$({
            cat "$references"
            printf '\0'
            cat "$required"
            printf '\0'
            cat "$cache_ttl_file"
          } | cksum)" || return

          local cache_fresh=false
          if [[ "''${OP_PROFILE_REFRESH:-0}" != 1 && -r "$cache" && -r "$cache_metadata" ]]; then
            local cached_signature now cache_mtime
            IFS= read -r cached_signature < "$cache_metadata"
            now="$(date +%s)" || return
            if cache_mtime="$(stat -c %Y "$cache" 2>/dev/null)" ||
              cache_mtime="$(stat -f %m "$cache" 2>/dev/null)"; then
              if [[ "$cached_signature" == "$signature" ]] &&
                (( now - cache_mtime < cache_ttl )); then
                cache_fresh=true
              fi
            fi
          fi

          if [[ "$cache_fresh" != true ]]; then
            local cache_tmp="$cache.tmp.$$"
            local metadata_tmp="$cache_metadata.tmp.$$"
            mkdir -p "$cache_root" || return
            chmod 0700 "$cache_root" || return
            rm -f "$cache_tmp" "$metadata_tmp"

            if ! op inject --in-file "$references" --out-file "$cache_tmp" --file-mode 0600; then
              rm -f "$cache_tmp" "$metadata_tmp"
              return 1
            fi
            if ! (umask 077 && printf '%s\n' "$signature" > "$metadata_tmp"); then
              rm -f "$cache_tmp" "$metadata_tmp"
              return 1
            fi
            mv "$cache_tmp" "$cache" || return
            mv "$metadata_tmp" "$cache_metadata" || return
          fi

          dotenv "$cache" || return
        fi

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
