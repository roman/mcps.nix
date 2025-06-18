{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    nixDir.url = "github:roman/nixDir/v3";

    devenv.url = "github:cachix/devenv";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ## Dependencies to build mcp-servers
    pyproject = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";
    systems.flake = false;
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [
        inputs.devenv.flakeModule
        inputs.nixDir.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];

      nixDir = {
        root = ./.;
        enable = true;
      };

      perSystem =
        { system, config, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ inputs.self.overlays.default ];
          };

          # overlayAttrs builds the default overlay.
          overlayAttrs = config.packages // {
            # Add necessary inputs to build packages from this flake.
            inherit (inputs) uv2nix pyproject pyproject-build-systems;
          };

          devenv.shells.default =
            { pkgs, ... }:
            {
              packages = [ pkgs.claude-code ];
              git-hooks.hooks = {
                nixfmt-rfc-style.enable = true;
              };
            };

        };
    };
}
