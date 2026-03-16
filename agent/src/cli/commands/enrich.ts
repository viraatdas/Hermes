import { Command } from "commander";
import { findMeeting } from "../../core/metadata-store.js";
import { readTranscriptByPath } from "../../core/transcript-reader.js";
import { enrichTranscript } from "../../enrichment/enrich.js";
import { writeEnrichment } from "../../enrichment/writer.js";
import { getRecordingsDir } from "../../core/config.js";
import { join } from "path";

export function enrichCommand(): Command {
  return new Command("enrich")
    .description("Enrich a meeting transcript with AI-generated summary, action items, and more")
    .argument("<identifier>", "Meeting title or ID")
    .option("--dry-run", "Print enrichment without writing to file")
    .action(async (identifier: string, opts) => {
      const meeting = await findMeeting(identifier);
      if (!meeting) {
        console.error(`Meeting "${identifier}" not found.`);
        process.exitCode = 1;
        return;
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
        console.error(`No transcript available for "${meeting.title}".`);
        process.exitCode = 1;
        return;
      }

      if (!transcript.trim()) {
        console.error(`Transcript is empty for "${meeting.title}".`);
        process.exitCode = 1;
        return;
      }

      console.error(`Enriching "${meeting.title}"...`);
      const enrichment = await enrichTranscript(meeting.title, transcript);

      if (opts.dryRun || !filePath) {
        console.log(JSON.stringify(enrichment, null, 2));
      } else {
        await writeEnrichment(filePath, enrichment);
        console.log(`Enrichment written to ${filePath}`);
        console.log(JSON.stringify(enrichment, null, 2));
      }
    });
}
