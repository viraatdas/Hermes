import { describe, it, expect, beforeEach, vi } from "vitest";

// We'll test the search helper functions by extracting the logic
// For integration tests, we'd need to mock the filesystem

describe("search", () => {
  describe("snippet extraction", () => {
    // Test the snippet extraction logic directly
    const SNIPPET_CONTEXT = 80;

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

    it("finds snippets with context", () => {
      const text = "The quick brown fox jumps over the lazy dog. The fox was very quick indeed.";
      const snippets = extractSnippets(text, "fox");
      expect(snippets.length).toBe(2);
      expect(snippets[0]).toContain("fox");
      expect(snippets[1]).toContain("fox");
    });

    it("returns empty for no match", () => {
      const snippets = extractSnippets("hello world", "xyz");
      expect(snippets).toHaveLength(0);
    });

    it("is case insensitive", () => {
      const snippets = extractSnippets("The FOX ran fast", "fox");
      expect(snippets.length).toBe(1);
      expect(snippets[0]).toContain("FOX");
    });

    it("limits to 3 snippets", () => {
      const text = "fox fox fox fox fox fox fox";
      const snippets = extractSnippets(text, "fox");
      expect(snippets.length).toBe(3);
    });
  });

  describe("scoring", () => {
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

    it("counts occurrences", () => {
      expect(scoreResult("fox fox fox", "fox")).toBe(3);
    });

    it("returns 0 for no match", () => {
      expect(scoreResult("hello world", "xyz")).toBe(0);
    });

    it("is case insensitive", () => {
      expect(scoreResult("FOX Fox fox", "fox")).toBe(3);
    });
  });
});
