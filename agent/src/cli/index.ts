import { Command } from "commander";
import { listCommand } from "./commands/list.js";
import { readCommand } from "./commands/read.js";
import { searchCommand } from "./commands/search.js";
import { enrichCommand } from "./commands/enrich.js";
import { serveCommand } from "./commands/serve.js";

export function createProgram(): Command {
  const program = new Command();

  program
    .name("hermes")
    .description("CLI for Hermes meeting transcripts")
    .version("0.1.0");

  program.addCommand(listCommand());
  program.addCommand(readCommand());
  program.addCommand(searchCommand());
  program.addCommand(enrichCommand());
  program.addCommand(serveCommand());

  return program;
}
