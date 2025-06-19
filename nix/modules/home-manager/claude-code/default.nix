{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;

  cfg = config.programs.claude-code;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = { };
  };
  extendedTools = baseTools.extend (cfg.extraTools or { });

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

  allServerConfigs = enabledPresetServers // cfg.mcp.servers;

  # ----------------------
  # MCP Sync Script Generation
  # ----------------------
  mcpSyncScript = pkgs.writeShellScriptBin "mcp-sync" ''
    set -euo pipefail

    # Function to check if we have any MCP servers configured
    has_mcp_servers() {
      ! ${cfg.package}/bin/claude mcp list 2>&1 | grep -q "No MCP servers configured"
    }

    # Function to get list of configured servers
    get_server_list() {
      ${cfg.package}/bin/claude mcp list | grep ': ' | cut -d':' -f1
    }

    echo "Synchronizing MCP servers configuration..."

    # Remove all existing MCP servers
    while has_mcp_servers; do
      echo "Removing existing MCP servers..."
      for server in $(get_server_list); do
        ${cfg.package}/bin/claude mcp remove --scope user "$server" > /dev/null
      done
    done

    echo "Installing configured MCP servers..."

    # Install new MCP server configurations
    ${lib.concatStrings (
      lib.mapAttrsToList (name: value: ''
        printf " - Installing ${name} "
        if ${cfg.package}/bin/claude mcp add-json --scope user "${name}" '${builtins.toJSON value}' > /dev/null 2>&1; then
          printf "✅\n"
        fi
      '') allServerConfigs
    )}
    echo "MCP servers synchronization completed!"
  '';

in
{
  options.programs.claude-code = {
    enable = mkEnableOption (lib.mdDoc "Enable claude-code");

    package = mkOption {
      type = types.package;
      default = pkgs.claude-code;
      description = lib.mdDoc "The claude-code package to use";
    };

    extraTools = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            package = mkOption {
              type = types.package;
              description = lib.mdDoc "The package containing the tool";
            };

            binary = mkOption {
              type = types.str;
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

    mcp = mkOption {
      type = types.submodule {
        imports = [
          (
            (
              { config, ... }:
              {
                options = presetOptionTypes // {
                  servers = mkOption {
                    type = types.attrsOf (types.submodule mcpServerOptionsType);
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
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.activation.mcpSync = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${mcpSyncScript}/bin/mcp-sync
    '';

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
  };
}
