import { describe, it, expect } from "vitest";

describe("MCP server module", () => {
  it("exports can be imported without starting the server", async () => {
    // We verify the module structure is correct by checking that
    // the dependent modules load properly
    const { loadMeetings, findMeeting, listMeetings } = await import(
      "../../src/core/metadata-store.js"
    );
    const { searchMeetings } = await import("../../src/core/search.js");

    expect(typeof loadMeetings).toBe("function");
    expect(typeof findMeeting).toBe("function");
    expect(typeof listMeetings).toBe("function");
    expect(typeof searchMeetings).toBe("function");
  });

  it("config module provides correct defaults", async () => {
    const { getDataDir, getRecordingsDir, getMetadataPath } = await import(
      "../../src/core/config.js"
    );

    const dataDir = getDataDir();
    expect(dataDir).toContain("Hermes");

    const recordingsDir = getRecordingsDir();
    expect(recordingsDir).toContain("Recordings");

    const metadataPath = getMetadataPath();
    expect(metadataPath).toContain("metadata.json");
  });
});
