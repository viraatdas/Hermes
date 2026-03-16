import Anthropic from "@anthropic-ai/sdk";
import { z } from "zod";
import { getAnthropicApiKey } from "../core/config.js";
import { ENRICHMENT_SYSTEM_PROMPT, buildEnrichmentPrompt } from "./prompts.js";
import type { MeetingEnrichment } from "../core/types.js";

const EnrichmentSchema = z.object({
  summary: z.string(),
  actionItems: z.array(z.string()),
  keyDecisions: z.array(z.string()),
  attendees: z.array(z.string()),
});

export async function enrichTranscript(
  title: string,
  transcript: string
): Promise<MeetingEnrichment> {
  const client = new Anthropic({ apiKey: getAnthropicApiKey() });

  const response = await client.messages.create({
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 1024,
    system: ENRICHMENT_SYSTEM_PROMPT,
    messages: [
      {
        role: "user",
        content: buildEnrichmentPrompt(title, transcript),
      },
    ],
  });

  const text =
    response.content[0].type === "text" ? response.content[0].text : "";

  // Extract JSON from the response (handle possible markdown code blocks)
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error("Failed to extract JSON from enrichment response");
  }

  const parsed = JSON.parse(jsonMatch[0]);
  return EnrichmentSchema.parse(parsed);
}
