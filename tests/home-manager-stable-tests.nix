{ inputs, system, ... }:

let
  apiKeyFilepath = "file.token";
  result = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs {
      inherit system;
      # overlays = [
      #   inputs.self.overlays.flake
      # ];
    };
    modules = [
      inputs.self.homeManagerModules.claude-code
      {
        nixpkgs.overlays = [
          inputs.self.overlays.flake
        ];
        home.stateVersion = "25.05";
        home.username = "jdoe";
        home.homeDirectory = "/test";
        programs.claude-code = {
          enable = true;
          mcp.buildkite = {
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
      name = "environment vars";
      type = "unit";
      expected = {
        "BUILDKITE_API_TOKEN_FILEPATH" = apiKeyFilepath;
      };
      actual = result.config.programs.claude-code.mcp.buildkite.mcpServer.env;
    }
    {
      name = "args";
      type = "unit";
      expected = [ "stdio" ];
      actual = result.config.programs.claude-code.mcp.buildkite.mcpServer.args;
    }
  ];
}
