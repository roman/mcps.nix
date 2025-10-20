{
  lib,
  callPackage,
  callPackages,
  fetchFromGitHub,

  uv2nix,
  pyproject,
  pyproject-build-systems,
  python311,
}:

let
  src = fetchFromGitHub {
    owner = "MarkusPfundstein";
    repo = "mcp-obsidian";
    rev = "4aac5c2b874a219652e783b13fde2fb89e9fb640";
    sha256 = "sha256-CWY4rgJZ8T6zRmJy8ueAk4Dg5QE7+BUSPamUuyAuXpw=";
  };

  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = builtins.toString src;
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
  venv = pythonSet.mkVirtualEnv "mcp-obsidian-venv" workspace.deps.default;
  package = pythonSet.mcp-obsidian;
}
