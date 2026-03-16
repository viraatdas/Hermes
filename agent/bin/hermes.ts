#!/usr/bin/env node

import { createProgram } from "../src/cli/index.js";

const program = createProgram();
program.parseAsync(process.argv).catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
