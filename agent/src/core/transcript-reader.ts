import { readFile } from "fs/promises";
import matter from "gray-matter";
import { resolve } from "path";
import { getRecordingsDir } from "./config.js";
import type { TranscriptDocument, TranscriptFrontmatter } from "./types.js";

export async function readTranscript(
  filePath: string
): Promise<TranscriptDocument> {
  // Resolve relative paths against the recordings directory
  const resolvedPath = resolve(getRecordingsDir(), filePath);
  const content = await readFile(resolvedPath, "utf-8");

  const { data, content: body } = matter(content);
  const frontmatter = data as TranscriptFrontmatter;

  // Extract raw transcript (everything after "## Transcript")
  const transcriptMatch = body.match(/## Transcript\s*\n([\s\S]*)/);
  const rawTranscript = transcriptMatch ? transcriptMatch[1].trim() : body.trim();

  return {
    frontmatter,
    title: frontmatter.title || "",
    rawTranscript,
    fullContent: content,
    filePath: resolvedPath,
  };
}

export async function readTranscriptByPath(
  absolutePath: string
): Promise<TranscriptDocument> {
  const content = await readFile(absolutePath, "utf-8");

  const { data, content: body } = matter(content);
  const frontmatter = data as TranscriptFrontmatter;

  const transcriptMatch = body.match(/## Transcript\s*\n([\s\S]*)/);
  const rawTranscript = transcriptMatch ? transcriptMatch[1].trim() : body.trim();

  return {
    frontmatter,
    title: frontmatter.title || "",
    rawTranscript,
    fullContent: content,
    filePath: absolutePath,
  };
}
