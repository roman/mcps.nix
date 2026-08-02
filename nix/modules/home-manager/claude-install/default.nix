{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkOption
    mkIf
    types
    ;

  claudeCfg = config.programs.claude-code;
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
    mkOption {
      type = lib.types.submodule preset;
      default = { };
      description = preset.meta.description or "MCP preset for ${name}";
    }
  ) presetDefinitions;

  # ----------------------
  # Server Configuration Management
  # ----------------------
  enabledPresetServers =
    let
      enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfg.mcps;
    in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

  allServerConfigs = enabledPresetServers // cfg.mcps.servers;

  # ----------------------
  # MCP Sync Script Generation
  # ----------------------
  # Generate the desired MCP servers JSON at build time
  allServerConfigsJson = builtins.toJSON allServerConfigs;

  mcpSyncScript = pkgs.writeShellScriptBin "mcp-sync" ''
    set -euo pipefail

    CLAUDE_CONFIG="$HOME/.claude.json"
    JQ="${pkgs.jq}/bin/jq"

    echo "Synchronizing MCP servers configuration..."

    # Ensure config file exists with valid JSON
    if [[ ! -f "$CLAUDE_CONFIG" ]]; then
      echo "{}" > "$CLAUDE_CONFIG"
    fi

    # Validate existing config is valid JSON, reset if not
    if ! $JQ empty "$CLAUDE_CONFIG" 2>/dev/null; then
      echo "Warning: Invalid JSON in $CLAUDE_CONFIG, resetting..."
      echo "{}" > "$CLAUDE_CONFIG"
    fi

    # Read the desired MCP servers configuration (generated at build time)
    DESIRED_SERVERS='${allServerConfigsJson}'

    # Update the config file: replace mcpServers entirely with desired config
    UPDATED_CONFIG=$($JQ --argjson servers "$DESIRED_SERVERS" '.mcpServers = $servers' "$CLAUDE_CONFIG")

    # Write back atomically
    echo "$UPDATED_CONFIG" > "$CLAUDE_CONFIG.tmp"
    mv "$CLAUDE_CONFIG.tmp" "$CLAUDE_CONFIG"

    # List installed servers
    echo "Installed MCP servers:"
    echo "$DESIRED_SERVERS" | $JQ -r 'keys[]' | while read -r server; do
      echo " - $server"
    done

    echo "MCP servers synchronization completed!"
  '';

in
{
  options.programs.claude-code.mcps = mkOption {
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
                  description = "Custom MCP server configurations";
                };
              };
            }
          )
        )
      ];
    };
    default = { };
    description = "MCP server configurations";
  };

  config = mkIf claudeCfg.enable {

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
