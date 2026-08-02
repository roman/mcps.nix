lib:
{ config, ... }:
{
  options = {
    type = lib.mkOption {
      type = lib.types.enum [
        "stdio"
        "sse"
      ];
      description = "Type of MCP server connection";
      example = "stdio";
    };

    url = lib.mkOption {
      type = lib.types.str;
      description = "URL where the MCP server-sent-events is hosted";
      default = "";
      example = "https://mcp.asana.com/sse";
    };

    command = lib.mkOption {
      type = lib.types.str;
      description = "Command to start the MCP server";
      default = "";
      example = "airchat";
    };

    args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Arguments to pass to the command";
      default = [ ];
      example = [
        "mcp"
        "start"
        "kb"
      ];
    };

    disabled = lib.mkOption {
      type = lib.types.bool;
      description = "Whether this MCP server is disabled";
      default = false;
    };

    timeoutMillis = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      description = "Timeout in milliseconds before killing the server";
      default = null;
      example = 3000;
    };

    env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = "Environment variables for the MCP server";
      default = { };
      example = {
        ASANA_ACCESS_TOKEN = "your-token-here";
      };
    };
  };
}
