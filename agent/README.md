# Hermes Agent

MCP server, CLI, and LLM enrichment for Hermes meeting transcripts.

## Setup

```bash
cd agent
npm install
npm run build
```

## CLI

```bash
# List meetings
node dist/bin/hermes.js list
node dist/bin/hermes.js list --today
node dist/bin/hermes.js list --week --limit 5

# Read a transcript
node dist/bin/hermes.js read "Morning Standup"

# Search across transcripts
node dist/bin/hermes.js search "API migration"

# Enrich a meeting with AI (requires ANTHROPIC_API_KEY)
export ANTHROPIC_API_KEY=sk-ant-...
node dist/bin/hermes.js enrich "Morning Standup"

# Start the MCP server
node dist/bin/hermes.js serve
```

## MCP Server

The MCP server exposes your meeting notes to AI tools via the [Model Context Protocol](https://modelcontextprotocol.io/).

### Tools

| Tool | Description |
|------|-------------|
| `search_meetings` | Full-text search across transcripts |
| `list_meetings` | List meetings with optional date filtering |
| `read_transcript` | Read full markdown transcript by title or ID |
| `get_meeting_summary` | Get parsed metadata and enrichment as JSON |
| `enrich_meeting` | Run LLM enrichment (requires ANTHROPIC_API_KEY) |

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "hermes": {
      "command": "node",
      "args": ["/path/to/Hermes/agent/dist/src/mcp/server.js"]
    }
  }
}
```

### Cursor

Add to `.cursor/mcp.json` in your project:

```json
{
  "mcpServers": {
    "hermes": {
      "command": "node",
      "args": ["/path/to/Hermes/agent/dist/src/mcp/server.js"]
    }
  }
}
```

### Claude Code

```bash
claude mcp add hermes node /path/to/Hermes/agent/dist/src/mcp/server.js
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `HERMES_DATA_DIR` | Path to Hermes data directory | `~/Documents/Hermes` |
| `ANTHROPIC_API_KEY` | Anthropic API key for enrichment | (required for enrich) |

## Development

```bash
npm run dev     # Watch mode
npm test        # Run tests
npm run build   # Build
```
