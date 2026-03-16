import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { loadMeetings, findMeeting, listMeetings } from "../core/metadata-store.js";
import { readTranscriptByPath } from "../core/transcript-reader.js";
import { searchMeetings } from "../core/search.js";
import { enrichTranscript } from "../enrichment/enrich.js";
import { writeEnrichment } from "../enrichment/writer.js";
import { getRecordingsDir } from "../core/config.js";
import { join } from "path";

// Redirect console.log to stderr — stdout is reserved for MCP JSON-RPC
const originalLog = console.log;
console.log = (...args: unknown[]) => {
  console.error(...args);
};

const server = new McpServer({
  name: "hermes",
  version: "0.1.0",
});

// --- Tools ---

server.tool(
  "search_meetings",
  "Full-text search across meeting transcripts. Returns matches with context snippets.",
  { query: z.string().describe("Search query text") },
  async ({ query }) => {
    const results = await searchMeetings(query);
    if (results.length === 0) {
      return { content: [{ type: "text", text: `No meetings found matching "${query}".` }] };
    }
    const text = results
      .slice(0, 10)
      .map((r) => {
        const snippets = r.snippets.map((s) => `  > ${s}`).join("\n");
        return `**${r.meeting.title}** (${r.meeting.formattedDate})\nScore: ${r.score}\n${snippets}`;
      })
      .join("\n\n---\n\n");
    return { content: [{ type: "text", text }] };
  }
);

server.tool(
  "list_meetings",
  "List recorded meetings with optional date filtering.",
  {
    startDate: z.string().optional().describe("ISO date string for start of range"),
    endDate: z.string().optional().describe("ISO date string for end of range"),
    limit: z.number().optional().describe("Maximum number of meetings to return"),
  },
  async ({ startDate, endDate, limit }) => {
    const meetings = await listMeetings({
      startDate: startDate ? new Date(startDate) : undefined,
      endDate: endDate ? new Date(endDate) : undefined,
      limit: limit ?? 20,
    });
    if (meetings.length === 0) {
      return { content: [{ type: "text", text: "No meetings found." }] };
    }
    const text = meetings
      .map(
        (m) =>
          `- **${m.title}** | ${m.formattedDate} | ${m.formattedDuration} | ID: ${m.id}`
      )
      .join("\n");
    return { content: [{ type: "text", text }] };
  }
);

server.tool(
  "read_transcript",
  "Read the full markdown transcript of a meeting by title or ID.",
  { identifier: z.string().describe("Meeting title or ID") },
  async ({ identifier }) => {
    const meeting = await findMeeting(identifier);
    if (!meeting) {
      return { content: [{ type: "text", text: `Meeting "${identifier}" not found.` }] };
    }
    if (!meeting.transcriptFilePath) {
      if (meeting.transcript) {
        return { content: [{ type: "text", text: meeting.transcript }] };
      }
      return { content: [{ type: "text", text: `No transcript available for "${meeting.title}".` }] };
    }
    const filePath = meeting.transcriptFilePath.startsWith("/")
      ? meeting.transcriptFilePath
      : join(getRecordingsDir(), meeting.transcriptFilePath);
    const doc = await readTranscriptByPath(filePath);
    return { content: [{ type: "text", text: doc.fullContent }] };
  }
);

server.tool(
  "get_meeting_summary",
  "Get parsed metadata and any enrichment sections for a meeting.",
  { identifier: z.string().describe("Meeting title or ID") },
  async ({ identifier }) => {
    const meeting = await findMeeting(identifier);
    if (!meeting) {
      return { content: [{ type: "text", text: `Meeting "${identifier}" not found.` }] };
    }

    const info: Record<string, unknown> = {
      id: meeting.id,
      title: meeting.title,
      date: meeting.formattedDate,
      duration: meeting.formattedDuration,
    };

    if (meeting.transcriptFilePath) {
      try {
        const filePath = meeting.transcriptFilePath.startsWith("/")
          ? meeting.transcriptFilePath
          : join(getRecordingsDir(), meeting.transcriptFilePath);
        const doc = await readTranscriptByPath(filePath);
        info.frontmatter = doc.frontmatter;

        // Extract enrichment sections if they exist
        const summaryMatch = doc.fullContent.match(/## Summary\n\n([\s\S]*?)(?=\n## |$)/);
        const actionsMatch = doc.fullContent.match(/## Action Items\n\n([\s\S]*?)(?=\n## |$)/);
        const decisionsMatch = doc.fullContent.match(/## Key Decisions\n\n([\s\S]*?)(?=\n## |$)/);
        const attendeesMatch = doc.fullContent.match(/## Attendees\n\n([\s\S]*?)(?=\n## |$)/);

        if (summaryMatch) info.summary = summaryMatch[1].trim();
        if (actionsMatch) info.actionItems = actionsMatch[1].trim();
        if (decisionsMatch) info.keyDecisions = decisionsMatch[1].trim();
        if (attendeesMatch) info.attendees = attendeesMatch[1].trim();
      } catch {
        // Transcript file not available
      }
    }

    return { content: [{ type: "text", text: JSON.stringify(info, null, 2) }] };
  }
);

server.tool(
  "enrich_meeting",
  "Run LLM enrichment on a meeting transcript to extract summary, action items, decisions, and attendees. Requires ANTHROPIC_API_KEY.",
  { identifier: z.string().describe("Meeting title or ID") },
  async ({ identifier }) => {
    const meeting = await findMeeting(identifier);
    if (!meeting) {
      return { content: [{ type: "text", text: `Meeting "${identifier}" not found.` }] };
    }

    let transcript = "";
    let filePath = "";

    if (meeting.transcriptFilePath) {
      filePath = meeting.transcriptFilePath.startsWith("/")
        ? meeting.transcriptFilePath
        : join(getRecordingsDir(), meeting.transcriptFilePath);
      const doc = await readTranscriptByPath(filePath);
      transcript = doc.rawTranscript;
    } else if (meeting.transcript) {
      transcript = meeting.transcript;
    } else {
      return { content: [{ type: "text", text: `No transcript available for "${meeting.title}".` }] };
    }

    if (!transcript.trim()) {
      return { content: [{ type: "text", text: `Transcript is empty for "${meeting.title}".` }] };
    }

    const enrichment = await enrichTranscript(meeting.title, transcript);

    if (filePath) {
      await writeEnrichment(filePath, enrichment);
    }

    return {
      content: [{ type: "text", text: JSON.stringify(enrichment, null, 2) }],
    };
  }
);

// --- Resources ---

server.resource(
  "meetings-list",
  "hermes://meetings",
  async (uri) => {
    const meetings = await loadMeetings();
    const text = meetings
      .map(
        (m) =>
          `${m.title} | ${m.formattedDate} | ${m.formattedDuration} | ID: ${m.id}`
      )
      .join("\n");
    return { contents: [{ uri: uri.href, text: text || "No meetings found." }] };
  }
);

// --- Start ---

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Hermes MCP server running on stdio");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
