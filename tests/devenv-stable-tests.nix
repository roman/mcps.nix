{ inputs, system, ... }:

let
  apiKeyFilepath = "file.token";
  config = inputs.devenv.lib.mkConfig {
    inherit inputs;
    pkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [
        inputs.self.overlays.flake
      ];
    };
    modules = [
      inputs.self.devenvModules.mcps
      {
        claude.code = {
          enable = true;
          mcps.buildkite = {
            enable = true;
            inherit apiKeyFilepath;
          };
        };
      }
    ];
  };
in
{
  tests = [
    {
      name = "command";
      type = "script";
      script = ''
        MCP_CONFIG="${config.files.".mcp.json".file}"
        CMD_ACTUAL="$(jq -r .mcpServers.buildkite.command $MCP_CONFIG)"
        CMD_EXPECTED="${config.claude.code.mcpServers.buildkite.command}"
        if [[ "$CMD_ACTUAL" != "$CMD_EXPECTED" ]]; then
           echo "claude does not have mcp server configured"
           exit 1
        fi 
      '';
    }
    {
      name = "environment vars";
      type = "unit";
      expected = {
        "BUILDKITE_API_TOKEN_FILEPATH" = apiKeyFilepath;
      };
      actual = config.claude.code.mcpServers.buildkite.env;
    }
    {
      name = "args";
      type = "unit";
      expected = [ "stdio" ];
      actual = config.claude.code.mcpServers.buildkite.args;
    }
  ];
}
