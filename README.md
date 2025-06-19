# Claude Code MCP Integration for Nix

A Nix-based integration system for [Claude Code](https://claude.ai/code) that provides
seamless configuration and management of MCP (Model Context Protocol) servers through
[devenv](https://github.com/cachix/devenv) and [Home
Manager](https://github.com/nix-community/home-manager).

## Features

- **Pre-configured MCP Servers**: Built-in support for popular MCP servers including Asana, GitHub, Grafana, Git, Filesystem, and more
- **Secure Credential Management**: Automatic handling of API tokens and credentials from files
- **devenv Integration**: Easy setup for development environments
- **Home Manager Support**: System-wide Claude Code configuration
- **Extensible**: Add custom MCP servers and tools

## Quick Start

Add this flake's overlay to your nixpkgs import.

```nix
let
  pkgs = import nixpkgs {
    overlays = [ claude-code.overlays.default ];
  };
in
# ...
```

### Using with devenv

Add to your devenv module configuration (assuming nix flakes)

```nix
{
  imports = [ inputs.claude-code.devenvModules.claude-code ];
  
  claude-code = {
    enable = true;
    mcp = {
      git.enable = true;
      filesystem = {
        enable = true;
        allowedPaths = [ "/path/to/your/project" ];
      };
      github = {
        enable = true;
        tokenFilepath = "/path/to/github-token";
      };
    };
  };
}
```

### Using with Home Manager

Add to your Home Manager configuration:

```nix
{
  imports = [ inputs.claude-code.homeManagerModules.claude-code ];
  
  programs.claude-code = {
    enable = true;
    mcp = {
      git.enable = true;
      filesystem = {
        enable = true;
        allowedPaths = [ "${config.home.homeDirectory}/Projects" ];
      };
      asana = {
        enable = true;
        tokenFilepath = "/var/run/agenix/asana.token";
      };
    };
  };
}
```

## Available MCP Servers

### Built-in Presets

| Preset | Description | Source |
|--------|-------------|--------|
| **asana** | Asana task management integration with API token support | [roychri/mcp-server-asana](https://github.com/roychri/mcp-server-asana) |
| **buildkite** | Buildkite CI/CD pipeline integration and monitoring | [buildkite/buildkite-mcp-server](https://github.com/buildkite/buildkite-mcp-server) |
| **fetch** | Web content fetching with proxy support and custom user agents | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **filesystem** | Local filesystem access with configurable path restrictions | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **git** | Git repository operations and version control | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **github** | GitHub API integration with configurable toolsets (repos, issues, users, pull_requests, code_security) | [github/github-mcp-server](https://github.com/github/github-mcp-server) |
| **grafana** | Grafana monitoring, alerting, and dashboard management with multiple toolsets | [grafana/mcp-grafana](https://github.com/grafana/mcp-grafana) |
| **lsp-golang** | Language Server Protocol integration for Go development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-nix** | Language Server Protocol integration for Nix development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-python** | Language Server Protocol integration for Python development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-rust** | Language Server Protocol integration for Rust development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **lsp-typescript** | Language Server Protocol integration for TypeScript development with configurable workspace | [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server) |
| **sequential-thinking** | Enhanced reasoning and knowledge graph capabilities | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |
| **time** | Time and timezone utilities with configurable local timezone | [modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers) |

## Custom MCP Servers

Add custom MCP servers using the `servers` attribute:

```nix
mcp.servers.my-custom-server = {
  type = "stdio";
  command = "${pkgs.my-mcp-server}/bin/server";
  args = [ "--option" "value" ];
  env = {
    API_KEY_FILE = "/path/to/api-key";
  };
};
```

## Extending with Custom Tools

Add custom tools that can be used by MCP servers:

```nix
programs.claude-code = {
  extraTools = {
    my-tool = {
      package = pkgs.my-custom-package;
      binary = "my-binary";
    };
  };
};
```

## Security Features

- **Credential File Support**: All MCP servers support reading credentials from files instead of environment variables
- **Path Restrictions**: Filesystem access is restricted to explicitly allowed paths
- **No Credential Exposure**: API tokens and keys are never exposed in the Nix store

## Contributing

See [CONTRIBUTE.md](./CONTRIBUTE.md) for development setup, testing, and contribution guidelines.

## License

This project is licensed under the MIT License.
