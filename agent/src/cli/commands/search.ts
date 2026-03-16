import { Command } from "commander";
import { searchMeetings } from "../../core/search.js";

const useColor = !process.env.NO_COLOR;

function bold(text: string): string {
  return useColor ? `\x1b[1m${text}\x1b[0m` : text;
}

function dim(text: string): string {
  return useColor ? `\x1b[2m${text}\x1b[0m` : text;
}

function yellow(text: string): string {
  return useColor ? `\x1b[33m${text}\x1b[0m` : text;
}

export function searchCommand(): Command {
  return new Command("search")
    .description("Search meeting transcripts")
    .argument("<query>", "Search query")
    .action(async (query: string) => {
      const results = await searchMeetings(query);

      if (results.length === 0) {
        console.log(`No results for "${query}".`);
        return;
      }

      console.log(bold(`${results.length} result(s) for "${query}":\n`));

      for (const result of results.slice(0, 10)) {
        console.log(
          bold(result.meeting.title) +
            "  " +
            dim(result.meeting.formattedDate) +
            "  " +
            dim(`(score: ${result.score})`)
        );

        for (const snippet of result.snippets) {
          console.log("  " + yellow(snippet));
        }

        console.log();
      }
    });
}
