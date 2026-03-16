import { readdir } from "fs/promises";
import { join } from "path";
import { getRecordingsDir } from "./config.js";
import { loadMeetings } from "./metadata-store.js";
import { readTranscriptByPath } from "./transcript-reader.js";
import type { SearchResult } from "./types.js";

const SNIPPET_CONTEXT = 80; // characters of context around match

function extractSnippets(text: string, query: string): string[] {
  const lower = text.toLowerCase();
  const queryLower = query.toLowerCase();
  const snippets: string[] = [];
  let pos = 0;

  while (snippets.length < 3) {
    const idx = lower.indexOf(queryLower, pos);
    if (idx === -1) break;

    const start = Math.max(0, idx - SNIPPET_CONTEXT);
    const end = Math.min(text.length, idx + query.length + SNIPPET_CONTEXT);
    let snippet = text.slice(start, end).replace(/\n/g, " ");
    if (start > 0) snippet = "..." + snippet;
    if (end < text.length) snippet = snippet + "...";
    snippets.push(snippet);

    pos = idx + query.length;
  }

  return snippets;
}

function scoreResult(text: string, query: string): number {
  const lower = text.toLowerCase();
  const queryLower = query.toLowerCase();
  let count = 0;
  let pos = 0;

  while (true) {
    const idx = lower.indexOf(queryLower, pos);
    if (idx === -1) break;
    count++;
    pos = idx + queryLower.length;
  }

  return count;
}

export async function searchMeetings(query: string): Promise<SearchResult[]> {
  const meetings = await loadMeetings();
  const recordingsDir = getRecordingsDir();
  const results: SearchResult[] = [];

  // Search through meetings that have transcript file paths
  const searchPromises = meetings.map(async (meeting) => {
    try {
      let text = "";
      let filePath = "";

      if (meeting.transcriptFilePath) {
        // Try reading the transcript file
        filePath = meeting.transcriptFilePath;
        if (!filePath.startsWith("/")) {
          filePath = join(recordingsDir, filePath);
        }
        const doc = await readTranscriptByPath(filePath);
        text = doc.fullContent;
      } else if (meeting.transcript) {
        // Fall back to inline transcript
        text = meeting.transcript;
        filePath = "";
      }

      // Also search in title
      text = meeting.title + "\n" + text;

      if (text.toLowerCase().includes(query.toLowerCase())) {
        return {
          meeting,
          snippets: extractSnippets(text, query),
          score: scoreResult(text, query),
          filePath,
        };
      }
    } catch {
      // File not found or unreadable — skip
    }
    return null;
  });

  // Also search .md files directly in recordings dir
  try {
    const files = await readdir(recordingsDir);
    const mdFiles = files.filter((f) => f.endsWith(".md"));

    const filePromises = mdFiles.map(async (file) => {
      const filePath = join(recordingsDir, file);
      // Skip if we already have this file from metadata
      if (
        meetings.some((m) => {
          const tp = m.transcriptFilePath || "";
          return tp === file || tp === filePath || tp.endsWith("/" + file);
        })
      ) {
        return null;
      }

      try {
        const doc = await readTranscriptByPath(filePath);
        const text = doc.title + "\n" + doc.fullContent;

        if (text.toLowerCase().includes(query.toLowerCase())) {
          return {
            meeting: {
              id: file,
              title: doc.title || file.replace(".md", ""),
              date: 0,
              duration: 0,
              audioFilePath: "",
              jsDate: new Date(doc.frontmatter.date || 0),
              formattedDate: doc.frontmatter.date || "Unknown",
              formattedDuration: doc.frontmatter.duration || "0:00",
            },
            snippets: extractSnippets(text, query),
            score: scoreResult(text, query),
            filePath,
          } as SearchResult;
        }
      } catch {
        // Skip unreadable files
      }
      return null;
    });

    const allResults = await Promise.all([...searchPromises, ...filePromises]);
    for (const r of allResults) {
      if (r) results.push(r);
    }
  } catch {
    // Recordings dir doesn't exist — just use metadata results
    const metadataResults = await Promise.all(searchPromises);
    for (const r of metadataResults) {
      if (r) results.push(r);
    }
  }

  // Sort by relevance score descending
  results.sort((a, b) => b.score - a.score);
  return results;
}
