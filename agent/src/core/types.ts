export interface RecordedMeeting {
  id: string;
  title: string;
  /** Apple epoch timestamp (seconds since Jan 1, 2001) in metadata.json */
  date: number;
  /** Duration in seconds */
  duration: number;
  audioFilePath: string;
  transcriptFilePath?: string;
  transcript?: string;
}

export interface ParsedMeeting extends RecordedMeeting {
  /** Converted JS Date */
  jsDate: Date;
  /** Formatted date string */
  formattedDate: string;
  /** Formatted duration string (MM:SS) */
  formattedDuration: string;
}

export interface TranscriptFrontmatter {
  title: string;
  date: string;
  duration: string;
  audio: string;
}

export interface TranscriptDocument {
  frontmatter: TranscriptFrontmatter;
  title: string;
  rawTranscript: string;
  fullContent: string;
  filePath: string;
}

export interface MeetingEnrichment {
  summary: string;
  actionItems: string[];
  keyDecisions: string[];
  attendees: string[];
}

export interface SearchResult {
  meeting: ParsedMeeting;
  snippets: string[];
  score: number;
  filePath: string;
}
