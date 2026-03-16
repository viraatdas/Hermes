import { readFile, stat } from "fs/promises";
import { getMetadataPath } from "./config.js";
import type { RecordedMeeting, ParsedMeeting } from "./types.js";

/** Apple epoch offset: seconds between Unix epoch (1970) and Apple epoch (2001) */
const APPLE_EPOCH_OFFSET = 978307200;

let cachedMeetings: ParsedMeeting[] | null = null;
let cachedMtime: number = 0;

export function appleEpochToDate(appleTimestamp: number): Date {
  return new Date((appleTimestamp + APPLE_EPOCH_OFFSET) * 1000);
}

export function dateToAppleEpoch(date: Date): number {
  return date.getTime() / 1000 - APPLE_EPOCH_OFFSET;
}

function formatDuration(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds) % 60;
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

function parseMeeting(raw: RecordedMeeting): ParsedMeeting {
  const jsDate = appleEpochToDate(raw.date);
  return {
    ...raw,
    jsDate,
    formattedDate: jsDate.toLocaleString("en-US", {
      dateStyle: "medium",
      timeStyle: "short",
    }),
    formattedDuration: formatDuration(raw.duration),
  };
}

export async function loadMeetings(
  forceReload = false
): Promise<ParsedMeeting[]> {
  const metadataPath = getMetadataPath();

  try {
    const fileStat = await stat(metadataPath);
    const mtime = fileStat.mtimeMs;

    if (!forceReload && cachedMeetings && mtime === cachedMtime) {
      return cachedMeetings;
    }

    const data = await readFile(metadataPath, "utf-8");
    const raw: RecordedMeeting[] = JSON.parse(data);

    cachedMeetings = raw
      .map(parseMeeting)
      .sort((a, b) => b.jsDate.getTime() - a.jsDate.getTime());
    cachedMtime = mtime;

    return cachedMeetings;
  } catch (err: unknown) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") {
      return [];
    }
    throw err;
  }
}

export async function findMeeting(
  identifier: string
): Promise<ParsedMeeting | undefined> {
  const meetings = await loadMeetings();

  // Try exact ID match first
  const byId = meetings.find((m) => m.id === identifier);
  if (byId) return byId;

  // Try case-insensitive title match
  const lower = identifier.toLowerCase();
  const byTitle = meetings.find((m) => m.title.toLowerCase() === lower);
  if (byTitle) return byTitle;

  // Try partial title match
  return meetings.find((m) => m.title.toLowerCase().includes(lower));
}

export async function listMeetings(options?: {
  startDate?: Date;
  endDate?: Date;
  limit?: number;
}): Promise<ParsedMeeting[]> {
  let meetings = await loadMeetings();

  if (options?.startDate) {
    meetings = meetings.filter((m) => m.jsDate >= options.startDate!);
  }
  if (options?.endDate) {
    meetings = meetings.filter((m) => m.jsDate <= options.endDate!);
  }
  if (options?.limit) {
    meetings = meetings.slice(0, options.limit);
  }

  return meetings;
}
