{
  inputs = {
    claude-code.url = "../../../";
    nixpkgs.follows = "claude-code/nixpkgs";
    flake-parts.follows = "claude-code/flake-parts";
    devenv.follows = "claude-code/devenv";
    systems.follows = "claude-code/systems";
    systems.flake = false;
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      debug = true;
      systems = import inputs.systems;
      imports = [ inputs.devenv.flakeModule ];

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

          devenv.shells.default = {
            imports = [ inputs.claude-code.devenvModules.claude-code ];
            claude-code = {
              enable = true;
              supportEmacs = true;
              mcp = {
                git.enable = true;
                fetch.enable = true;
              };
            };
          };
        };
    };
}
