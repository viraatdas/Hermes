import { homedir } from "os";
import { join } from "path";

export function getDataDir(): string {
  return process.env.HERMES_DATA_DIR || join(homedir(), "Documents", "Hermes");
}

export function getRecordingsDir(): string {
  return join(getDataDir(), "Recordings");
}

export function getMetadataPath(): string {
  return join(getDataDir(), "metadata.json");
}

export function getAnthropicApiKey(): string {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) {
    throw new Error(
      "ANTHROPIC_API_KEY environment variable is required for enrichment. " +
        "Set it with: export ANTHROPIC_API_KEY=sk-ant-..."
    );
  }
  return key;
}
