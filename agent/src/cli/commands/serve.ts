import { Command } from "commander";

export function serveCommand(): Command {
  return new Command("serve")
    .description("Start the Hermes MCP server (stdio transport)")
    .action(async () => {
      // Dynamic import to avoid loading MCP dependencies for other commands
      await import("../../mcp/server.js");
    });
}
