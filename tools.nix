{
  pkgs,
  lib,
  inputs,
  extraTools ? { },
}:

let
  wrapWithCredentialFiles = pkgs.callPackage ./nix/lib/wrapWithCredentialFiles.nix { };

  mkTool =
    { package, binary }:
    {
      inherit package binary;
      path = "${lib.getBin package}/bin/${binary}";
    };

  toolsFunctions = {
    # Helper to map credential environment variables to files containing credentials
    inherit wrapWithCredentialFiles;

    # Helper for creating new tool entries (exposed for extension)
    inherit mkTool;

    # Function to get a tool by name, with error checking
    getTool =
      name:
      let
        tool = builtins.getAttr name tools;
      in
      if tool.package == null then
        throw "Tool ${name} is not available in your mcp tools configuration"
      else
        tool.package;

    # Function to get a tool's command path
    getToolPath =
      name:
      let
        tool = builtins.getAttr name tools;
      in
      if tool.package == null then
        throw "Tool ${name} is not available in your mcp tools configuration"
      else
        tool.path;

    # Function to create a new tools set with additional tools
    extend =
      newExtraTools:
      import ./tools.nix {
        inherit pkgs lib inputs;
        extraTools = extraTools // newExtraTools;
      };

  };

  baseTools = {

    asana = mkTool {
      # Override vanilla mpc-server-asana with script that allow us to read credentials from
      # a file and populate it on the ASANA_ACCESS_TOKEN.
      package = wrapWithCredentialFiles {
        package = pkgs.mcp-server-asana;
        credentialEnvs = [ "ASANA_ACCESS_TOKEN" ];
      };
      binary = "mcp-server-asana";
    };

    github = mkTool {
      # Override vanilla github-mpc-server with script that allow us to read credentials
      # from a file and populate it on the GITHUB_PERSONAL_ACCESS_TOKEN.
      package = wrapWithCredentialFiles {
        package = pkgs.github-mcp-server;
        credentialEnvs = [ "GITHUB_PERSONAL_ACCESS_TOKEN" ];
      };
      binary = "github-mcp-server";
    };

    grafana = mkTool {
      package = wrapWithCredentialFiles {
        package = pkgs.mcp-grafana;
        credentialEnvs = [ "GRAFANA_API_KEY" ];
      };
      binary = "mcp-grafana";
    };

    filesystem = mkTool {
      package = pkgs.mcp-servers;
      binary = "mcp-server-filesystem";
    };

    git = mkTool {
      package = pkgs.mcp-servers;
      binary = "mcp-server-git";
    };

    fetch = mkTool {
      package = pkgs.mcp-servers;
      binary = "mcp-server-fetch";
    };

    sequential-thinking = mkTool {
      package = pkgs.mcp-servers;
      binary = "mcp-server-sequentialthinking";
    };

    time = mkTool {
      package = pkgs.mcp-servers;
      binary = "mcp-server-time";
    };

    buildkite = mkTool {
      package = wrapWithCredentialFiles {
        package = pkgs.buildkite-mcp-server;
        credentialEnvs = [ "BUILDKITE_API_TOKEN" ];
      };
      binary = "buildkite-mcp-server";
    };

  };

  # Combined tools (base + extra)
  tools = baseTools // extraTools;

in
tools // toolsFunctions
