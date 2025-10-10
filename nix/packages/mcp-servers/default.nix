{
  uv2nix,
  pyproject,
  pyproject-build-systems,
  lib,
  callPackage,
  callPackages,
  fetchFromGitHub,
  buildNpmPackage,
  nodejs,
  nodePackages,
  python311,
  symlinkJoin,
}:

let
  version = "2025.9.25";
  masterSrc = fetchFromGitHub {
    owner = "modelcontextprotocol";
    repo = "servers";
    rev = version;
    sha256 = "sha256-ysTuSHFs7GABMuFXG+DcyonVXVs7m45j9sDPdHBS2wQ=";
  };

  gitServer =
    let
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = "${masterSrc}/src/git";
      };
      workspaceOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      pythonSet =
        (callPackage pyproject.build.packages {
          python = python311;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              workspaceOverlay
            ]
          );
      inherit (callPackages pyproject.build.util { }) mkApplication;
    in
    mkApplication {
      venv = pythonSet.mkVirtualEnv "mcp-server-git-venv" workspace.deps.default;
      package = pythonSet.mcp-server-git;
    };

  timeServer =
    let
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = "${masterSrc}/src/time";
      };
      workspaceOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      pythonSet =
        (callPackage pyproject.build.packages {
          python = python311;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              workspaceOverlay
            ]
          );
      inherit (callPackages pyproject.build.util { }) mkApplication;
    in
    mkApplication {
      venv = pythonSet.mkVirtualEnv "mcp-server-time-venv" workspace.deps.default;
      package = pythonSet.mcp-server-time;
    };

  fetchServer =
    let
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = "${masterSrc}/src/fetch";
      };
      workspaceOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };
      pythonSet =
        (callPackage pyproject.build.packages {
          python = python311;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.default
              workspaceOverlay
            ]
          );
      inherit (callPackages pyproject.build.util { }) mkApplication;
    in
    mkApplication {
      venv = pythonSet.mkVirtualEnv "mcp-server-fetch-venv" workspace.deps.default;
      package = pythonSet.mcp-server-fetch;
    };

  # todo: remove once/if shx is in pkgs.nodePackages
  shx =
    let
      version = "7c2dd8ce765ffb6b42964c9d8541706829487c90";
    in
    buildNpmPackage {
      pname = "shx";
      inherit version;
      src = fetchFromGitHub {
        owner = "shelljs";
        repo = "shx";
        rev = version;
        hash = "sha256-QGq6WqjozgU9AxosDyTe7wrl+sulccxIN9AohoS+Zc0=";
      };
      dontNpmBuild = true;
      npmDepsHash = "sha256-R1fn1TH4FntPnMd40AUGYIPLSZX18sQ7fKzTU3zSEd0=";
      meta = with lib; {
        description = "Portable Shell Commands for Node";
        homepage = "https://github.com/shelljs/shx";
        license = licenses.mit;
        maintainers = with maintainers; [ roman ];
      };
    };

  jsServers = buildNpmPackage {
    pname = "mcp-servers";
    inherit version;
    src = "${masterSrc}";
    npmDepsHash = "sha256-iRPILytyloL6qRMvy2fsDdqkewyqEfcuVspwUN5Lrqw=";
    PUPPETEER_SKIP_DOWNLOAD = 1;
    nativeBuildInputs = [
      nodePackages.npm
      nodePackages.typescript
      shx
    ];
    buildInputs = [ nodejs ];
    installPhase = ''
      mkdir $out
      mkdir $out/bin
      cp -R src $out
      cp -R node_modules $out
      ln -s $out/node_modules/@modelcontextprotocol/server-filesystem/dist/index.js $out/bin/mcp-server-filesystem 
      ln -s $out/node_modules/@modelcontextprotocol/server-everything/dist/index.js $out/bin/mcp-server-everything
      ln -s $out/node_modules/@modelcontextprotocol/server-memory/dist/index.js $out/bin/mcp-server-memory
      ln -s $out/node_modules/@modelcontextprotocol/server-memory/dist/index.js $out/bin/mcp-server-sequentialthinking
    '';
    meta = with lib; {
      description = "Model Context Protocol servers";
      homepage = "https://modelcontextprotocol.io";
      license = licenses.mit;
      maintainers = with maintainers; [ roman ];
    };
  };

in
symlinkJoin {
  name = "mcp-servers";
  paths = [
    gitServer
    fetchServer
    timeServer
    jsServers
  ];
}
