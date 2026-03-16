import { describe, it, expect, beforeEach, vi } from "vitest";
import { appleEpochToDate, dateToAppleEpoch } from "../../src/core/metadata-store.js";

describe("metadata-store", () => {
  describe("appleEpochToDate", () => {
    it("converts Apple epoch timestamp to JS Date", () => {
      // Jan 1, 2001 00:00:00 UTC in Apple epoch = 0
      const date = appleEpochToDate(0);
      expect(date.toISOString()).toBe("2001-01-01T00:00:00.000Z");
    });

    it("converts a known timestamp", () => {
      // 796723200 Apple epoch = Apr 2, 2026 (978307200 + 796723200 = 1775030400 Unix)
      const date = appleEpochToDate(796723200);
      expect(date.getFullYear()).toBe(2026);
      // Just verify it's a valid date in 2026
      expect(date.getTime()).toBe(1775030400000);
    });
  });

  describe("dateToAppleEpoch", () => {
    it("round-trips correctly", () => {
      const original = 796723200;
      const date = appleEpochToDate(original);
      const back = dateToAppleEpoch(date);
      expect(back).toBe(original);
    });

    it("converts Jan 1, 2001 to 0", () => {
      const date = new Date("2001-01-01T00:00:00.000Z");
      expect(dateToAppleEpoch(date)).toBe(0);
    });
  });
});
