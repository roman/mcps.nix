{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule (finalAttrs: {
  pname = "mcp-language-server";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "isaacphi";
    repo = "mcp-language-server";
    tag = "v${finalAttrs.version}";
    hash = "sha256-T0wuPSShJqVW+CcQHQuZnh3JOwqUxAKv1OCHwZMr7KM=";
  };
  vendorHash = "sha256-3NEG9o5AF2ZEFWkA9Gub8vn6DNptN6DwVcn/oR8ujW0=";
  subPackages = [ "." ];

  doInstallCheck = true;

  meta = {
    changelog = "https://github.com/isaacphi/mcp-language-server/releases/tag/v${finalAttrs.version}";
    description = "mcp-language-server gives MCP enabled clients access semantic tools like get definition, references, rename, and diagnostics.";
    homepage = "https://github.com/isaacphi/mcp-language-server";
    license = lib.licenses.bsd3;
    mainProgram = "mcp-language-server";
    maintainers = with lib.maintainers; [ roman ];
  };
})
