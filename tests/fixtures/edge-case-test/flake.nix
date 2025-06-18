{
  inputs = {
    claude-code.url = "../../";
    nixpkgs.follows = "claude-code/nixpkgs";
    flake-parts.follows = "claude-code/flake-parts";
    devenv.follows = "claude-code/devenv";
    systems.follows = "claude-code/systems";
    systems.flake = false;
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;
      imports = [ inputs.devenv.flakeModule ];

      perSystem =
        { pkgs, ... }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit (pkgs.stdenv.hostPlatform) system;
            overlays = [ inputs.claude-code.overlays.default ];
          };

          devenv.shells.invalid-stdio = {
            imports = [ inputs.claude-code.devenvModules.claude-code ];
            claude-code = {
              enable = true;
              mcp.servers.broken-stdio = {
                type = "stdio";
                # Missing required command - should fail assertion
              };
            };
          };

          devenv.shells.invalid-sse = {
            imports = [ inputs.claude-code.devenvModules.claude-code ];
            claude-code = {
              enable = true;
              mcp.servers.broken-sse = {
                type = "sse";
                # Missing required url - should fail assertion
              };
            };
          };
        };
    };
}
