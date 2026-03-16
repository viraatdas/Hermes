import { Command } from "commander";
import { listMeetings } from "../../core/metadata-store.js";

const useColor = !process.env.NO_COLOR;

function dim(text: string): string {
  return useColor ? `\x1b[2m${text}\x1b[0m` : text;
}

function bold(text: string): string {
  return useColor ? `\x1b[1m${text}\x1b[0m` : text;
}

export function listCommand(): Command {
  return new Command("list")
    .description("List recorded meetings")
    .option("--today", "Show only today's meetings")
    .option("--week", "Show only this week's meetings")
    .option("-n, --limit <number>", "Maximum number of meetings", "20")
    .action(async (opts) => {
      let startDate: Date | undefined;
      const now = new Date();

      if (opts.today) {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      } else if (opts.week) {
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - now.getDay());
      }

      const meetings = await listMeetings({
        startDate,
        limit: parseInt(opts.limit, 10),
      });

      if (meetings.length === 0) {
        console.log("No meetings found.");
        return;
      }

      // Table header
      console.log(
        bold("Title".padEnd(40)) +
          bold("Date".padEnd(24)) +
          bold("Duration".padEnd(10)) +
          bold("ID")
      );
      console.log(dim("-".repeat(90)));

      for (const m of meetings) {
        const title = m.title.length > 38 ? m.title.slice(0, 37) + "…" : m.title;
        console.log(
          title.padEnd(40) +
            dim(m.formattedDate.padEnd(24)) +
            dim(m.formattedDuration.padEnd(10)) +
            dim(m.id.slice(0, 8))
        );
      }

      console.log(dim(`\n${meetings.length} meeting(s)`));
    });
}
