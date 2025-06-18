{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    devenv.url = "github:cachix/devenv";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs = {
      nixpkgs.follows = "nixpkgs";
    };

    claude-code.url = "../../.";

    systems.url = "github:nix-systems/default";
    systems.flake = false;
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {

      debug = true;
      systems = import inputs.systems;

      imports = [
        inputs.devenv.flakeModule
      ];

      perSystem =
        {
          pkgs,
          system,
          self',
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              (_final: _prev: { flakeInputs = inputs; })
              inputs.claude-code.overlays.default
            ];
          };

          devenv.shells.default =
            {
              pkgs,
              lib,
              config,
              ...
            }:
            {
              imports = [
                inputs.claude-code.devenvModules.claude-code
              ];

              claude-code = {
                enable = true;
                forceOverride = true;
                supportEmacs = true;
                mcp = {
                  asana = {
                    enable = true;
                    tokenFilepath = "/var/run/agenix/asana.token";
                  };
                  github = {
                    enable = true;
                    baseURL = "https://git.company-dev.com";
                    tokenFilepath = "/var/run/agenix/git.musta.ch.token";
                  };
                  grafana = {
                    enable = true;
                    baseURL = "https://localhost:3000";
                    apiKeyFilepath = "/var/run/agenix/grafana-api.key";
                    toolsets = [ "search" ];
                  };
                  fetch.enable = true;
                  git.enable = true;
                  sequential-thinking.enable = true;
                  time = {
                    enable = true;
                    # localTimezone = "America/Vancouver";
                  };
                };
              };
            };
        };
    };
}
