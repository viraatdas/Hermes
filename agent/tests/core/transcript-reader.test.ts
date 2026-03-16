import { describe, it, expect } from "vitest";
import { readTranscriptByPath } from "../../src/core/transcript-reader.js";
import { join } from "path";

const FIXTURES = join(import.meta.dirname, "..", "fixtures");

describe("transcript-reader", () => {
  it("parses frontmatter from a transcript file", async () => {
    const doc = await readTranscriptByPath(join(FIXTURES, "standup_2026-03-16.md"));

    expect(doc.frontmatter.title).toBe("Morning Standup");
    // gray-matter parses ISO dates as Date objects
    expect(new Date(doc.frontmatter.date).toISOString()).toBe("2026-03-16T09:00:00.000Z");
    expect(doc.frontmatter.duration).toBe("12:34");
    expect(doc.frontmatter.audio).toBe("standup_2026-03-16.m4a");
  });

  it("extracts raw transcript content", async () => {
    const doc = await readTranscriptByPath(join(FIXTURES, "standup_2026-03-16.md"));

    expect(doc.rawTranscript).toContain("Sarah mentioned the API migration");
    expect(doc.rawTranscript).toContain("auth service");
    // Should not include the header or frontmatter
    expect(doc.rawTranscript).not.toContain("---");
    expect(doc.rawTranscript).not.toContain("**Date:**");
  });

  it("sets title from frontmatter", async () => {
    const doc = await readTranscriptByPath(join(FIXTURES, "standup_2026-03-16.md"));
    expect(doc.title).toBe("Morning Standup");
  });

  it("preserves full content", async () => {
    const doc = await readTranscriptByPath(join(FIXTURES, "standup_2026-03-16.md"));
    expect(doc.fullContent).toContain("---");
    expect(doc.fullContent).toContain("## Transcript");
    expect(doc.fullContent).toContain("Sarah mentioned");
  });
});
