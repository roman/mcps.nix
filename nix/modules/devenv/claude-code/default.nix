{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:

let
  # ----------------------
  # Configuration Options
  # ----------------------
  cfg = config.claude-code;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix { inherit pkgs inputs lib; };
  extendedTools = baseTools.extend (cfg.extraTools or { });

  presetRequiredTools = lib.unique (
    lib.flatten (
      lib.mapAttrsToList (_: preset: preset._module.args.requiredTools or [ ]) (
        lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfg.mcp
      )
    )
  );

  toolPackages = map (name: extendedTools.getTool name) presetRequiredTools;

  # ----------------------
  # Preset Management
  # ----------------------
  mcpServerOptionsType = import ../../../lib/mcp-server-options.nix lib;
  presetDefinitions = import ../../../../presets.nix {
    inherit config lib pkgs;
    tools = extendedTools;
  };

  presetOptionTypes = lib.mapAttrs (
    name: preset:
    lib.mkOption {
      type = lib.types.submodule preset;
      default = { };
      description = lib.mdDoc (preset.meta.description or "MCP preset for ${name}");
    }
  ) presetDefinitions;

  # ----------------------
  # Server Configuration Management
  # ----------------------
  enabledPresetServers =
    let
      enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfg.mcp;
    in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

  allServerConfigs = enabledPresetServers // cfg.mcp.servers // cfg.mcpServers;

  # ----------------------
  # Configuration File Generation
  # ----------------------
  mcpConfigFile = pkgs.writeTextFile {
    name = "mcp-config";
    destination = "/mcp.json";
    text = builtins.toJSON {
      mcpServers = lib.mapAttrs (
        name: serverCfg:
        let
          isValidConfigValue =
            optName: optValue:
            optValue != null
            && (optName != "env" || optValue != { })
            && (optName != "command" || optValue != "" || serverCfg.type == "stdio");
        in
        lib.filterAttrs isValidConfigValue serverCfg
      ) allServerConfigs;
    };
  };

  # ----------------------
  # Emacs Integration
  # ----------------------
  emacsConfigGenerator = {
    envToKeywords =
      env:
      let
        toKeywordPair = name: value: ":${lib.toUpper name} \"${toString value}\"";
        pairs = lib.mapAttrsToList toKeywordPair env;
      in
      if pairs == [ ] then "" else ":env (${lib.concatStringsSep " " pairs})";

    serverToConfig =
      name: cfg:
      let
        properties = lib.concatStringsSep " " (
          lib.filter (x: x != "") [
            (lib.optionalString (cfg.command != null) ":command \"${cfg.command}\"")
            (lib.optionalString (cfg.args != null && cfg.args != [ ])
              ":args '(${lib.concatMapStringsSep " " (arg: "\"${arg}\"") cfg.args})"
            )
            (if cfg.env != null && cfg.env != { } then emacsConfigGenerator.envToKeywords cfg.env else "")
          ]
        );
      in
      ''("${name}" . (${properties}))'';
  };

  dirLocalsFile = pkgs.writeText "dir-locals.el" ''
    ;;; Directory Local Variables
    ;;; For more information see (info "(emacs) Directory Variables")

    ((nil . ((mcp-hub-servers . (
      ${lib.concatStringsSep "\n      " (
        lib.mapAttrsToList emacsConfigGenerator.serverToConfig allServerConfigs
      )}
    )))))
  '';

in
{
  options.claude-code = {
    enable = lib.mkEnableOption (lib.mdDoc "enable claude-code");

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.claude-code;
      description = lib.mdDoc "The claude-code package to use";
    };

    extraTools = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            package = lib.mkOption {
              type = lib.types.package;
              description = lib.mdDoc "The package containing the tool";
            };

            binary = lib.mkOption {
              type = lib.types.str;
              description = lib.mdDoc "The name of the binary within the package";
            };
          };
        }
      );
      default = { };
      description = lib.mdDoc "Additional tools to make available for MCP servers";
      example = lib.literalExpression ''
        {
          my-custom-mcp = {
            package = pkgs.my-custom-mcp;
            binary = "mcp-binary-name";
          };
        }
      '';
    };

    mcp = lib.mkOption {
      type = lib.types.submodule {
        imports = [
          (
            (
              { config, ... }:
              {
                options = presetOptionTypes // {
                  servers = lib.mkOption {
                    type = lib.types.attrsOf (lib.types.submodule mcpServerOptionsType);
                    default = { };
                    description = lib.mdDoc "Custom MCP server configurations";
                  };
                };
              }
            )
          )
        ];
      };
      default = { };
      description = lib.mdDoc "MCP server configurations";
    };

    mcpServers = lib.mkOption {
      type = lib.types.lazyAttrsOf (lib.types.submodule mcpServerOptionsType);
      default = { };
      description = lib.mdDoc "Legacy configuration for MCP servers (use mcp.servers instead)";
      example = lib.literalExpression ''
        {
          asana = {
            type = "stdio";
            command = "mcp-server-asana";
            env = {
              ASANA_ACCESS_TOKEN = "your-token-here";
            };
          };
        }
      '';
    };

    supportEmacs = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to generate and manage .dir-locals.el file with mcp.el setup";
    };

    forceOverride = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "Whether to force override existing files";
    };

  };

  config = lib.mkMerge [
    {
      scripts.gen-mcp-configurations = {
        exec = ''
          MCP_CONFIG_PATH="${mcpConfigFile}/mcp.json"
          MCP_DEST_PATH="$DEVENV_ROOT/.mcp.json"
          MCP_BACKUP_PATH="$DEVENV_ROOT/.mcp.json.backup"
          DIR_LOCALS_PATH="$DEVENV_ROOT/.dir-locals.el"
          DIR_LOCALS_BACKUP_PATH="$DEVENV_ROOT/.dir-locals.el.backup"

          # Array to store change messages
          declare -a CHANGES=()

          manage_config_file() {
            local dest_path="$1"
            local backup_path="$2"
            local nix_path="$3"
            local should_enable="$4"

            local current_target
            current_target=$(get_target_path "$dest_path")
            local new_target
            new_target=$(get_target_path "$nix_path")

            # If file exists and is a symlink to nix store
            if [ -L "$dest_path" ] && is_nix_store_path "$dest_path"; then
              if [ "$should_enable" = "false" ]; then
                rm "$dest_path"
                if [ -f "$backup_path" ]; then
                  mv "$backup_path" "$dest_path"
                  CHANGES+=(" • ⏮️ Restored \x1B[1m$(basename $dest_path)\x1B[0m from backup")
                else
                  CHANGES+=(" • 🔥 Removed Nix-managed \x1B[1m$(basename $dest_path)\x1B[0m")
                fi
                return
              fi
            fi

            if [ "$should_enable" = "true" ]; then
              if [ -e "$dest_path" ]; then
                if [ "$current_target" = "$new_target" ]; then
                  return
                fi

                if ! is_nix_store_path "$dest_path"; then
                  cp -L "$dest_path" "$backup_path"
                  CHANGES+=(" • ⏭️ Backed up existing \x1B[1m$(basename $dest_path)\x1B[0m to \x1B[1m$(basename $backup_path)\x1B[0m")
                  ln -sfn "$nix_path" "$dest_path"
                  CHANGES+=(" • ✅ Created new Nix-managed \x1B[1m$(basename $dest_path)\x1B[0m configuration")
                  return
                fi
                if ${if cfg.forceOverride then "true" else "false"}; then
                  ln -sfn "$nix_path" "$dest_path"
                  CHANGES+=(" • ✅️ Updated Nix-managed \x1B[1m$(basename $dest_path)\x1B[0m configuration to latest version")
                else
                  CHANGES+=(" • ⚠️ Keeping existing Nix-managed \x1B[1m$(basename $dest_path)\x1B[0m file (use forceOverride to replace)")
                fi
              else
                ln -sfn "$nix_path" "$dest_path"
                CHANGES+=(" • ✅ Created new Nix-managed \x1B[1m$(basename $dest_path)\x1B[0m configuration")
              fi
            fi
          }

          is_nix_store_path() {
            local target_path=$(readlink -f "$1" 2>/dev/null)
            [[ "$target_path" == /nix/store/* ]]
          }

          get_target_path() {
            readlink -f "$1" 2>/dev/null || echo ""
          }

          print_changes() {
            if [ ''${#CHANGES[@]} -gt 0 ]; then
              # Print header
              echo ""
              echo -e "\x1B[32;1mclaude-code.nix\x1B[0m - Managing MCP configuration files"
              echo "Ensuring configuration files are in sync with current settings..."
              echo ""

              # Print all accumulated changes
              printf '%b\n' "''${CHANGES[@]}"
              echo ""
            fi
                                                  }

          # Always manage .mcp.json when claude-code is enabled
          manage_config_file "$MCP_DEST_PATH" "$MCP_BACKUP_PATH" "$MCP_CONFIG_PATH" "${
            if cfg.enable then "true" else "false"
          }"

          # Manage .dir-locals.el based on supportEmacs option
          manage_config_file "$DIR_LOCALS_PATH" "$DIR_LOCALS_BACKUP_PATH" "${dirLocalsFile}" "${
            if cfg.enable && cfg.supportEmacs then "true" else "false"
          }"

          # Print changes only if there are any
          print_changes
        '';
        description = "Manage MCP configuration files (.mcp.json and optionally .dir-locals.el)";
      };

      enterShell = ''
        gen-mcp-configurations
      '';
    }
    (lib.mkIf cfg.enable {
      packages = [ cfg.package ] ++ toolPackages;

      assertions = lib.flatten (
        lib.mapAttrsToList (name: serverCfg: [
          {
            assertion = (serverCfg.type != "stdio") || (serverCfg.command != "");
            message = "Command must be specified when type is 'stdio' for MCP server '${name}'";
          }
          {
            assertion = (serverCfg.type != "sse") || (serverCfg.url != "");
            message = "URL must be specified when type is 'sse' for MCP server '${name}'";
          }
        ]) allServerConfigs
      );
    })
  ];
}
