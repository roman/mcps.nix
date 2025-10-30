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
    foldl'
    attrNames
    ;

  claudeCfg = config.claude.code;
  cfg = config.claude.code.mcps;

  # ----------------------
  # Tools Management
  # ----------------------
  baseTools = import ../../../../tools.nix {
    inherit pkgs lib;
    inputs = { };
  };

  # ----------------------
  # Preset Management
  # ----------------------
  mcpServerOptionsType = import ../../../lib/mcp-server-options.nix lib;
  presetDefinitions = import ../../../../presets.nix {
    inherit config lib pkgs;
    tools = baseTools;
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
      enabledPresets = lib.filterAttrs (name: preset: name != "servers" && preset.enable) cfg;
    in
    lib.mapAttrs (_: preset: preset.mcpServer) enabledPresets;

in
{
  options.claude.code.mcps = mkOption {
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

  config = mkIf claudeCfg.enable {
    claude.code.mcpServers = foldl' (
      acc: presetName:
      acc
      // {
        "${presetName}" = {
          inherit (enabledPresetServers.${presetName})
            command
            args
            env
            type
            url
            ;
        };
      }
    ) { } (attrNames enabledPresetServers);
  };
}
