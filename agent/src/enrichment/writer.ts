import { readFile, writeFile } from "fs/promises";
import type { MeetingEnrichment } from "../core/types.js";

function formatEnrichment(enrichment: MeetingEnrichment): string {
  const sections: string[] = [];

  sections.push(`## Summary\n\n${enrichment.summary}`);

  if (enrichment.actionItems.length > 0) {
    const items = enrichment.actionItems.map((item) => `- [ ] ${item}`).join("\n");
    sections.push(`## Action Items\n\n${items}`);
  }

  if (enrichment.keyDecisions.length > 0) {
    const decisions = enrichment.keyDecisions.map((d) => `- ${d}`).join("\n");
    sections.push(`## Key Decisions\n\n${decisions}`);
  }

  if (enrichment.attendees.length > 0) {
    const attendees = enrichment.attendees.map((a) => `- ${a}`).join("\n");
    sections.push(`## Attendees\n\n${attendees}`);
  }

  return sections.join("\n\n");
}

export async function writeEnrichment(
  filePath: string,
  enrichment: MeetingEnrichment
): Promise<void> {
  const content = await readFile(filePath, "utf-8");
  const enrichmentBlock = formatEnrichment(enrichment);

  // Remove existing enrichment sections if present
  const cleaned = content
    .replace(/\n## Summary\n[\s\S]*?(?=\n## (?!Summary|Action Items|Key Decisions|Attendees)|$)/, "")
    .replace(/\n## Action Items\n[\s\S]*?(?=\n## (?!Summary|Action Items|Key Decisions|Attendees)|$)/, "")
    .replace(/\n## Key Decisions\n[\s\S]*?(?=\n## (?!Summary|Action Items|Key Decisions|Attendees)|$)/, "")
    .replace(/\n## Attendees\n[\s\S]*?(?=\n## (?!Summary|Action Items|Key Decisions|Attendees)|$)/, "");

  const newContent = cleaned.trimEnd() + "\n\n" + enrichmentBlock + "\n";
  await writeFile(filePath, newContent, "utf-8");
}
