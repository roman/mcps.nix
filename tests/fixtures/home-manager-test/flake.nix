{
  inputs = {
    claude-code.url = "../../../";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    nixpkgs.follows = "claude-code/nixpkgs";
    devenv.follows = "claude-code/devenv";
    flake-parts.follows = "claude-code/flake-parts";
    systems.follows = "claude-code/systems";
    systems.flake = false;
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = import inputs.systems;
      imports = [ inputs.devenv.flakeModule ];

      flake = {
        homeConfigurations.test = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
          modules = [
            inputs.claude-code.homeManagerModules.claude-code
            {
              nixpkgs = {
                config.allowUnfree = true;
                overlays = [
                  inputs.claude-code.overlays.default
                ];
              };
              home.username = "testuser";
              home.homeDirectory = "/home/testuser";
              home.stateVersion = "23.11";

              programs.claude-code = {
                enable = true;
                mcp = {
                  git.enable = true;
                  fetch.enable = true;
                  filesystem = {
                    enable = true;
                    allowedPaths = [ "/tmp" ];
                  };
                  lsp-typescript = {
                    enable = true;
                    workspace = "/tmp/test-ts-workspace";
                  };
                };
              };
            }
          ];
        };
      };

      perSystem =
        { system, pkgs, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              inputs.claude-code.overlays.default
            ];
          };
        };
    };
}
