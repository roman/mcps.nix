{ lib, tools, ... }:

let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    ;
  mcpServerOptionsType = import ./nix/lib/mcp-server-options.nix lib;

  # Helper to transform a simple preset definition into a full module
  mkPresetModule =
    {
      name,
      description ? "MCP integration for ${name}",
      options ? { },
      env ? (_: { }),
      command,
      args ? (_: [ ]),
    }:
    { config, ... }:
    {
      options = {
        enable = mkEnableOption description;

        timeoutMillis = mkOption {
          type = types.nullOr types.int;
          default = 5000;
          description = lib.mdDoc "Timeout in milliseconds";
        };

        mcpServer = lib.mkOption {
          type = lib.types.submodule mcpServerOptionsType;
          default = { };
          description = lib.mdDoc "MCP server configuration";
        };
      } // options;

      config = mkIf config.enable {
        mcpServer = {
          type = "stdio";
          inherit command;
          inherit (config) timeoutMillis;
          args = args config;
          env = env config;
        };
      };
    };

  # Simple preset definitions
  presets = {

    asana = {
      name = "Asana";
      command = tools.getToolPath "asana";
      env = config: {
        ASANA_ACCESS_TOKEN_FILEPATH = config.tokenFilepath;
      };
      options = {
        tokenFilepath = mkOption {
          type = types.str;
          description = lib.mdDoc "File containing Asana API access token";
          example = "/var/run/agenix/asana.token";
        };
      };
    };

    filesystem = {
      name = "Filesystem";
      command = tools.getToolPath "filesystem";
      args = config: config.allowedPaths;
      options = {
        allowedPaths = mkOption {
          type = types.nonEmptyListOf types.str;
          description = lib.mdDoc "List of allowed filepaths that your agent can explore";
          example = [ "/Users/jdoe/Projects" ];
        };
      };
    };

    git = {
      name = "Git";
      command = tools.getToolPath "git";
      env = config: {
        # Reset PYTHONPATH to avoid environmental dependencies affecting the runtime
        # of this application.
        PYTHONPATH = "";
      };
    };

    fetch = {
      name = "Fetch";
      command = tools.getToolPath "fetch";
      args =
        config:
        (lib.optionals (config.userAgent != null) [
          "--user-agent"
          config.userAgent
        ])
        ++ (lib.optionals (config.proxyURL != null) [
          "--proxy-url"
          config.proxyURL
        ])
        ++ (lib.optionals config.ignoreRobotsTxt [ "--ignore-robots-txt" ]);
      options = {
        proxyURL = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = lib.mdDoc "Proxy URL to use for requests";
          example = "https://localhost:3000";
        };
        ignoreRobotsTxt = mkOption {
          type = types.bool;
          default = false;
          description = lib.mdDoc "Ignore robots.txt restrictions";
          example = false;
        };
        userAgent = mkOption {
          type = types.nullOr types.str;
          description = lib.mdDoc "Custom User-Agent string";
          default = null;
          example = "claude-code";
        };
      };
    };

    sequential-thinking = {
      name = "Sequential Thinking";
      command = tools.getToolPath "sequential-thinking";
    };

    time = {
      name = "Time";
      command = tools.getToolPath "time";
      args =
        config:
        lib.optionals (config.localTimezone != null) [
          "--local-timezone"
          config.localTimezone
        ];

      options = {
        localTimezone = mkOption {
          type = types.str;
          description = lib.mdDoc "Timezone used by the server";
          example = "America/New_York";
        };
      };
    };

    github = {
      name = "GitHub";
      command = tools.getToolPath "github";
      args = config: [
        "stdio"
        "--toolsets"
        (builtins.concatStringsSep "," config.toolsets)
      ];
      env =
        config:
        {
          GITHUB_PERSONAL_ACCESS_TOKEN_FILEPATH = config.tokenFilepath;
        }
        // (lib.optionalAttrs (config.baseURL != null && config.baseURL != "") {
          GITHUB_HOST = config.baseURL;
        });
      options = {
        tokenFilepath = mkOption {
          type = types.str;
          description = lib.mdDoc "File containing GitHub API access token";
          example = "/var/run/agenix/gh-personal-access.token";
        };

        baseURL = mkOption {
          type = types.nullOr types.str;
          description = lib.mdDoc "Use it for GitHub Enterprise Cloud installs";
          example = "https://<your GHES or ghe.com domain name>";
        };

        toolsets = mkOption {
          type = types.nonEmptyListOf (
            types.enum [
              "repos"
              "issues"
              "users"
              "pull_requests"
              "code_security"
            ]
          );
          default = [
            "repos"
            "pull_requests"
            "users"
          ];
          description = lib.mdDoc "List of GitHub toolsets to enable";
        };
      };
    };

    grafana = {
      name = "Grafana";
      command = tools.getToolPath "grafana";
      args =
        config:
        [
          "-enabled-tools"
          (builtins.concatStringsSep "," config.toolsets)
        ]
        ++ (lib.optionals config.debug [ "-debug" ]);

      env = config: {
        GRAFANA_URL = config.baseURL;
        GRAFANA_API_KEY_FILEPATH = config.apiKeyFilepath;
      };

      options = {
        apiKeyFilepath = mkOption {
          type = types.str;
          description = lib.mdDoc "File containing Grafana API key";
          example = "/var/run/agenix/grafana-api.key";
        };

        baseURL = mkOption {
          type = types.str;
          description = lib.mdDoc "URL where the Grafana host lives";
          example = "https://localhost:3000";
        };

        toolsets = mkOption {
          type = types.nonEmptyListOf (
            types.enum [
              "search"
              "datasource"
              "incident"
              "prometheus"
              "loki"
              "alerting"
              "dashboard"
              "oncall"
              "asserts"
              "sift"
              "admin"
            ]
          );
          default = [
            "prometheus"
            "search"
            "datasource"
          ];
          description = lib.mdDoc "List of Grafana toolsets to enable";
        };

        debug = mkOption {
          type = types.bool;
          description = lib.mdDoc "Enable debug mode for the Grafana transport";
          default = false;
          example = "true";
        };
      };
    };

    buildkite = {
      name = "Buildkite";
      command = tools.getToolPath "buildkite";
      args = config: [ "stdio" ];
      env = config: {
        BUILDKITE_API_TOKEN_FILEPATH = config.apiKeyFilepath;
      };
      options = {
        apiKeyFilepath = mkOption {
          type = types.str;
          description = lib.mdDoc "File containing Buildkit API token";
          example = "/var/run/agenix/buildkite-api.token";
        };
      };
    };

  };

in
lib.mapAttrs (_: mkPresetModule) presets
