import { Command } from "commander";
import { findMeeting } from "../../core/metadata-store.js";
import { readTranscriptByPath } from "../../core/transcript-reader.js";
import { getRecordingsDir } from "../../core/config.js";
import { join } from "path";

export function readCommand(): Command {
  return new Command("read")
    .description("Read a meeting transcript")
    .argument("<identifier>", "Meeting title or ID")
    .action(async (identifier: string) => {
      const meeting = await findMeeting(identifier);
      if (!meeting) {
        console.error(`Meeting "${identifier}" not found.`);
        process.exitCode = 1;
        return;
      }

      if (meeting.transcriptFilePath) {
        const filePath = meeting.transcriptFilePath.startsWith("/")
          ? meeting.transcriptFilePath
          : join(getRecordingsDir(), meeting.transcriptFilePath);
        const doc = await readTranscriptByPath(filePath);
        console.log(doc.fullContent);
      } else if (meeting.transcript) {
        console.log(meeting.transcript);
      } else {
        console.error(`No transcript available for "${meeting.title}".`);
        process.exitCode = 1;
      }
    });
}
