{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "buildkite-mcp-server";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "buildkite";
    repo = "buildkite-mcp-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-D+QWGH3RDdBBGXxmBihQ/yjMIaKxGfPrTwjOWx6p6Vs=";
  };

  vendorHash = "sha256-3G74RvFon/MA8BGMTgtaRP6kG0YgBDzrijzKD4pq31w=";

  env.CGO_ENABLED = 0;

  patches = [ ./buildkite-mcp.patch ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  doInstallCheck = true;

  meta = {
    changelog = "https://github.com/buildkite/buildkite-mcp-server/releases/tag/v${finalAttrs.version}";
    description = "Official MCP Server for Buildkite.";
    homepage = "https://github.com/buildkite/buildkite-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "buildkite-mcp-server";
    maintainers = with lib.maintainers; [ roman ];
  };
})
